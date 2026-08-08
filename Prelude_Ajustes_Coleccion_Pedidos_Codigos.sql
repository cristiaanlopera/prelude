-- PRELUDE · AJUSTES DE COLECCIÓN, PEDIDOS Y CÓDIGOS
-- Ejecutar UNA VEZ en Supabase → SQL Editor → New query → Run.
-- Es acumulativo sobre Prelude_Studio_Fase2_Pedidos.sql.

-- 1) Notificaciones persistentes para mostrar, una sola vez, las nuevas obras desbloqueadas.
create table if not exists public.prelude_artwork_notifications (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.prelude_customers(id) on delete cascade,
  order_id uuid null references public.prelude_orders(id) on delete cascade,
  perfume text not null,
  order_number text null,
  seen_at timestamptz null,
  created_at timestamptz not null default now()
);
create index if not exists prelude_artwork_notifications_customer_idx
  on public.prelude_artwork_notifications(customer_id, seen_at, created_at);
alter table public.prelude_artwork_notifications enable row level security;
revoke all on table public.prelude_artwork_notifications from anon;
revoke all on table public.prelude_artwork_notifications from authenticated;

-- 2) Historial de pedidos visible para el propio cliente.
create or replace function public.get_prelude_customer_orders(
  input_phone text,
  input_access_token uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  customer_row public.prelude_customers%rowtype;
  result jsonb;
begin
  select * into customer_row
  from public.prelude_customers
  where regexp_replace(customer_phone,'[^0-9]','','g') = regexp_replace(coalesce(input_phone,''),'[^0-9]','','g')
    and access_token = input_access_token
  limit 1;

  if not found then raise exception 'Perfil Prelude no válido.'; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',o.id,
    'order_number',o.order_number,
    'delivery_zone',o.delivery_zone,
    'items',o.items,
    'order_total',o.order_total,
    'status',o.status,
    'created_at',o.created_at,
    'updated_at',o.updated_at,
    'delivered_at',o.delivered_at
  ) order by o.created_at desc),'[]'::jsonb)
  into result
  from public.prelude_orders o
  where o.customer_id = customer_row.id;

  return result;
end;
$$;
revoke all on function public.get_prelude_customer_orders(text,uuid) from public;
grant execute on function public.get_prelude_customer_orders(text,uuid) to anon;
grant execute on function public.get_prelude_customer_orders(text,uuid) to authenticated;

-- 3) Leer y marcar las obras pendientes de presentar al cliente.
create or replace function public.get_pending_prelude_artwork_notifications(
  input_phone text,
  input_access_token uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  customer_row public.prelude_customers%rowtype;
  result jsonb;
begin
  select * into customer_row
  from public.prelude_customers
  where regexp_replace(customer_phone,'[^0-9]','','g') = regexp_replace(coalesce(input_phone,''),'[^0-9]','','g')
    and access_token = input_access_token
  limit 1;
  if not found then raise exception 'Perfil Prelude no válido.'; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',n.id,'perfume',n.perfume,'order_number',n.order_number,'created_at',n.created_at
  ) order by n.created_at asc),'[]'::jsonb)
  into result
  from public.prelude_artwork_notifications n
  where n.customer_id=customer_row.id and n.seen_at is null;
  return result;
end;
$$;
revoke all on function public.get_pending_prelude_artwork_notifications(text,uuid) from public;
grant execute on function public.get_pending_prelude_artwork_notifications(text,uuid) to anon;
grant execute on function public.get_pending_prelude_artwork_notifications(text,uuid) to authenticated;

create or replace function public.mark_prelude_artwork_notifications_seen(
  input_phone text,
  input_access_token uuid,
  input_notification_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare customer_row public.prelude_customers%rowtype; updated_count integer;
begin
  select * into customer_row from public.prelude_customers
  where regexp_replace(customer_phone,'[^0-9]','','g')=regexp_replace(coalesce(input_phone,''),'[^0-9]','','g')
    and access_token=input_access_token limit 1;
  if not found then raise exception 'Perfil Prelude no válido.'; end if;

  update public.prelude_artwork_notifications
  set seen_at=coalesce(seen_at,now())
  where customer_id=customer_row.id and id=any(coalesce(input_notification_ids,'{}'::uuid[]));
  get diagnostics updated_count = row_count;
  return jsonb_build_object('success',true,'updated',updated_count);
end;
$$;
revoke all on function public.mark_prelude_artwork_notifications_seen(text,uuid,uuid[]) from public;
grant execute on function public.mark_prelude_artwork_notifications_seen(text,uuid,uuid[]) to anon;
grant execute on function public.mark_prelude_artwork_notifications_seen(text,uuid,uuid[]) to authenticated;

-- 4) Estado de pedido reversible.
-- ENTREGADO: incorpora las obras y contabiliza gasto/marcapáginas.
-- Si deja de estar ENTREGADO: revierte exclusivamente lo aportado por ese pedido.
create or replace function public.admin_update_prelude_order_status(input_order_id uuid,input_status text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  o public.prelude_orders%rowtype;
  item jsonb;
  perfume_name text;
  points integer;
  inserted_count integer;
  replacement_order_number text;
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then
    raise exception 'No tienes permisos de administrador.';
  end if;
  if input_status not in ('pending','preparing','ready','delivered','cancelled') then raise exception 'Estado no válido.'; end if;

  select * into o from public.prelude_orders where id=input_order_id for update;
  if not found then raise exception 'Pedido no encontrado.'; end if;

  -- Revertir antes de cambiar el estado si el pedido ya estaba contabilizado como entregado.
  if o.status='delivered' and input_status<>'delivered' and o.customer_id is not null and o.accounted_at is not null then
    points := floor(coalesce(o.order_total,0))::integer;
    update public.prelude_customers
      set total_spent=greatest(0,coalesce(total_spent,0)-coalesce(o.order_total,0)),
          bookmarks=greatest(0,coalesce(bookmarks,0)-points)
      where id=o.customer_id;

    for item in select value from jsonb_array_elements(o.items)
    loop
      perfume_name := nullif(trim(item->>'name'),'');
      if perfume_name is null then continue; end if;

      -- Solo tocamos la obra si este pedido era su fuente actual.
      if exists(select 1 from public.prelude_customer_library l where l.customer_id=o.customer_id and l.perfume=perfume_name and l.source_code='ORDER-'||o.order_number) then
        replacement_order_number := null;
        select other.order_number into replacement_order_number
        from public.prelude_orders other
        where other.customer_id=o.customer_id
          and other.id<>o.id
          and other.status='delivered'
          and exists(select 1 from jsonb_array_elements(other.items) oi where trim(oi->>'name')=perfume_name)
        order by other.delivered_at desc nulls last, other.created_at desc
        limit 1;

        if replacement_order_number is not null then
          update public.prelude_customer_library
          set source_code='ORDER-'||replacement_order_number
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

  update public.prelude_orders
  set status=input_status,
      updated_at=now(),
      delivered_at=case when input_status='delivered' then coalesce(delivered_at,now()) else null end
  where id=input_order_id;

  select * into o from public.prelude_orders where id=input_order_id for update;

  -- Entrega / reentrega.
  if input_status='delivered' and o.customer_id is not null and o.accounted_at is null then
    for item in select value from jsonb_array_elements(o.items)
    loop
      perfume_name := nullif(trim(item->>'name'),'');
      if perfume_name is not null then
        insert into public.prelude_customer_library(customer_id,perfume,source_code)
        values(o.customer_id,perfume_name,'ORDER-'||o.order_number)
        on conflict (customer_id,perfume) do nothing;
        get diagnostics inserted_count = row_count;

        if inserted_count>0 then
          insert into public.prelude_artwork_notifications(customer_id,order_id,perfume,order_number)
          values(o.customer_id,o.id,perfume_name,o.order_number);
        end if;
      end if;
    end loop;

    points := floor(coalesce(o.order_total,0))::integer;
    update public.prelude_customers
      set total_spent=coalesce(total_spent,0)+coalesce(o.order_total,0),
          bookmarks=coalesce(bookmarks,0)+points
      where id=o.customer_id;
    update public.prelude_orders set accounted_at=now() where id=input_order_id;
  end if;

  select * into o from public.prelude_orders where id=input_order_id;
  return jsonb_build_object('success',true,'id',o.id,'order_number',o.order_number,'status',o.status,'accounted_at',o.accounted_at,'delivered_at',o.delivered_at);
end;
$$;
revoke all on function public.admin_update_prelude_order_status(uuid,text) from public;
grant execute on function public.admin_update_prelude_order_status(uuid,text) to authenticated;

-- 5) Eliminar códigos antiguos/de prueba desde Prelude Studio.
create or replace function public.admin_delete_prelude_code(input_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare deleted_count integer;
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then
    raise exception 'No tienes permisos de administrador.';
  end if;
  delete from public.prelude_codes where code=trim(input_code);
  get diagnostics deleted_count=row_count;
  return jsonb_build_object('success',deleted_count>0,'deleted',deleted_count,'code',trim(input_code));
end;
$$;
revoke all on function public.admin_delete_prelude_code(text) from public;
grant execute on function public.admin_delete_prelude_code(text) to authenticated;

-- 6) Importar los dos pedidos históricos indicados.
-- No se inventan productos, zona ni estado: quedan como pedidos históricos pendientes de completar/confirmar.
do $$
declare cid uuid;
begin
  if not exists(select 1 from public.prelude_orders where order_number='P-H001') then
    select id into cid from public.prelude_customers where lower(customer_name) like 'alfonso%' order by created_at asc limit 1;
    insert into public.prelude_orders(order_number,customer_id,customer_name,delivery_zone,notes,items,order_total,status)
    values('P-H001',cid,'Alfonso','Sin especificar','Pedido histórico importado. Falta completar detalle de productos, zona y estado real.','[]'::jsonb,24.37,'pending');
  end if;
end $$;

do $$
declare cid uuid;
begin
  if not exists(select 1 from public.prelude_orders where order_number='P-H002') then
    select id into cid from public.prelude_customers where lower(customer_name) like 'luis%' order by created_at asc limit 1;
    insert into public.prelude_orders(order_number,customer_id,customer_name,delivery_zone,notes,items,order_total,status)
    values('P-H002',cid,'Luis','Sin especificar','Pedido histórico importado. Falta completar detalle de productos, zona y estado real.','[]'::jsonb,3.06,'pending');
  end if;
end $$;
