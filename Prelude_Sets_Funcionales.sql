-- PRELUDE · SETS FUNCIONALES + STUDIO
-- Ejecutar UNA VEZ en Supabase SQL Editor antes de desplegar esta versión.

create table if not exists public.prelude_sets(
  id text primary key,
  name text not null,
  active boolean not null default true,
  discount_percent numeric(5,2) not null default 0 check(discount_percent>=0 and discount_percent<=50),
  bonus_bookmarks integer not null default 0 check(bonus_bookmarks>=0),
  product_ids jsonb not null default '[]'::jsonb check(jsonb_typeof(product_ids)='array'),
  display_order integer not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.prelude_sets enable row level security;
revoke all on table public.prelude_sets from anon,authenticated;

insert into public.prelude_sets(id,name,active,discount_percent,bonus_bookmarks,product_ids,display_order) values
('five','The Five',true,5,5,'[]',1),
('discovery','The Discovery',true,10,5,'[]',2),
('journey','The Journey',true,10,5,'[]',3),
('match','The Match',true,5,5,'[]',4),
('curator','The Curator',true,10,5,'[]',5)
on conflict(id) do nothing;

create or replace function public.get_prelude_sets()
returns jsonb
language sql
security definer
set search_path=public
as $$
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',s.id,'name',s.name,'active',s.active,'discount_percent',s.discount_percent,
  'bonus_bookmarks',s.bonus_bookmarks,'product_ids',s.product_ids,'display_order',s.display_order
 ) order by s.display_order),'[]'::jsonb)
 from public.prelude_sets s;
$$;
revoke all on function public.get_prelude_sets() from public;
grant execute on function public.get_prelude_sets() to anon,authenticated;

create or replace function public.admin_list_prelude_sets()
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare result jsonb;
begin
 if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then
  raise exception 'No tienes permisos de administrador.';
 end if;
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',s.id,'name',s.name,'active',s.active,'discount_percent',s.discount_percent,
  'bonus_bookmarks',s.bonus_bookmarks,'product_ids',s.product_ids,'display_order',s.display_order
 ) order by s.display_order),'[]'::jsonb) into result from public.prelude_sets s;
 return result;
end;
$$;
revoke all on function public.admin_list_prelude_sets() from public;
grant execute on function public.admin_list_prelude_sets() to authenticated;

create or replace function public.admin_update_prelude_set(
 input_id text,input_active boolean,input_discount_percent numeric,input_bonus_bookmarks integer,input_product_ids text[]
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare ids jsonb;
begin
 if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then
  raise exception 'No tienes permisos de administrador.';
 end if;
 if input_id not in ('five','discovery','journey','match','curator') then raise exception 'Set no válido.'; end if;
 if coalesce(input_discount_percent,0)<0 or input_discount_percent>50 then raise exception 'Descuento no válido.'; end if;
 if coalesce(input_bonus_bookmarks,0)<0 then raise exception 'Bonus no válido.'; end if;
 ids=coalesce(to_jsonb(input_product_ids),'[]'::jsonb);
 update public.prelude_sets set active=coalesce(input_active,false),discount_percent=round(coalesce(input_discount_percent,0),2),
  bonus_bookmarks=coalesce(input_bonus_bookmarks,0),product_ids=ids,updated_at=now() where id=input_id;
 if not found then raise exception 'Set no encontrado.'; end if;
 return jsonb_build_object('success',true,'id',input_id);
end;
$$;
revoke all on function public.admin_update_prelude_set(text,boolean,numeric,integer,text[]) from public;
grant execute on function public.admin_update_prelude_set(text,boolean,numeric,integer,text[]) to authenticated;

-- Sustituye la función de cambio de estado para sumar/restar el bonus de Prelude Sets
-- una sola vez por Set, además de los Marcapáginas normales del pedido.
create or replace function public.admin_update_prelude_order_status(input_order_id uuid,input_status text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  o public.prelude_orders%rowtype;
  item jsonb;
  perfume_name text;
  points integer;
  set_bonus integer:=0;
  inserted_count integer;
  replacement_order_number text;
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then
    raise exception 'No tienes permisos de administrador.';
  end if;
  if input_status not in ('pending','preparing','ready','delivered','cancelled') then raise exception 'Estado no válido.'; end if;

  select * into o from public.prelude_orders where id=input_order_id for update;
  if not found then raise exception 'Pedido no encontrado.'; end if;

  select coalesce(sum(x.bonus),0)::integer into set_bonus
  from (
    select item->>'set_instance' as instance,
      max(case when coalesce(item->>'set_bonus_bookmarks','') ~ '^[0-9]+$' then (item->>'set_bonus_bookmarks')::integer else 0 end) as bonus
    from jsonb_array_elements(o.items) item
    where nullif(item->>'set_instance','') is not null
    group by item->>'set_instance'
  ) x;

  if o.status='delivered' and input_status<>'delivered' and o.customer_id is not null and o.accounted_at is not null then
    points := floor(coalesce(o.order_total,0))::integer + set_bonus;
    update public.prelude_customers
      set total_spent=greatest(0,coalesce(total_spent,0)-coalesce(o.order_total,0)),
          bookmarks=greatest(0,coalesce(bookmarks,0)-points)
      where id=o.customer_id;

    for item in select value from jsonb_array_elements(o.items)
    loop
      perfume_name := nullif(trim(item->>'name'),'');
      if perfume_name is null then continue; end if;
      if exists(select 1 from public.prelude_customer_library l where l.customer_id=o.customer_id and l.perfume=perfume_name and l.source_code='ORDER-'||o.order_number) then
        replacement_order_number := null;
        select other.order_number into replacement_order_number
        from public.prelude_orders other
        where other.customer_id=o.customer_id and other.id<>o.id and other.status='delivered'
          and exists(select 1 from jsonb_array_elements(other.items) oi where trim(oi->>'name')=perfume_name)
        order by other.delivered_at desc nulls last,other.created_at desc limit 1;
        if replacement_order_number is not null then
          update public.prelude_customer_library set source_code='ORDER-'||replacement_order_number
          where customer_id=o.customer_id and perfume=perfume_name and source_code='ORDER-'||o.order_number;
        else
          delete from public.prelude_customer_library
          where customer_id=o.customer_id and perfume=perfume_name and source_code='ORDER-'||o.order_number;
        end if;
      end if;
    end loop;
    delete from public.prelude_artwork_notifications where order_id=o.id;
    update public.prelude_orders set accounted_at=null,delivered_at=null where id=o.id;
  end if;

  update public.prelude_orders set status=input_status,updated_at=now(),
    delivered_at=case when input_status='delivered' then coalesce(delivered_at,now()) else null end
  where id=input_order_id;

  select * into o from public.prelude_orders where id=input_order_id for update;

  if input_status='delivered' and o.customer_id is not null and o.accounted_at is null then
    for item in select value from jsonb_array_elements(o.items)
    loop
      perfume_name := nullif(trim(item->>'name'),'');
      if perfume_name is not null then
        insert into public.prelude_customer_library(customer_id,perfume,source_code)
        values(o.customer_id,perfume_name,'ORDER-'||o.order_number)
        on conflict(customer_id,perfume) do nothing;
        get diagnostics inserted_count=row_count;
        if inserted_count>0 then
          insert into public.prelude_artwork_notifications(customer_id,order_id,perfume,order_number)
          values(o.customer_id,o.id,perfume_name,o.order_number);
        end if;
      end if;
    end loop;

    points := floor(coalesce(o.order_total,0))::integer + set_bonus;
    update public.prelude_customers set
      total_spent=coalesce(total_spent,0)+coalesce(o.order_total,0),
      bookmarks=coalesce(bookmarks,0)+points
    where id=o.customer_id;
    update public.prelude_orders set accounted_at=now() where id=input_order_id;
  end if;

  select * into o from public.prelude_orders where id=input_order_id;
  return jsonb_build_object('success',true,'id',o.id,'order_number',o.order_number,'status',o.status,'accounted_at',o.accounted_at,'delivered_at',o.delivered_at,'set_bonus_bookmarks',set_bonus);
end;
$$;
revoke all on function public.admin_update_prelude_order_status(uuid,text) from public;
grant execute on function public.admin_update_prelude_order_status(uuid,text) to authenticated;
