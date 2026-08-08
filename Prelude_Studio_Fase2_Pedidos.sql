-- PRELUDE STUDIO · FASE 2 — PEDIDOS
-- Ejecuta este script UNA VEZ en Supabase → SQL Editor → New query → Run.
-- Requiere que ya existan public.prelude_admins, public.prelude_customers y public.prelude_customer_library.

create extension if not exists pgcrypto;

create sequence if not exists public.prelude_order_number_seq start 1;

create table if not exists public.prelude_orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  customer_id uuid null references public.prelude_customers(id) on delete set null,
  customer_name text not null,
  customer_phone text null,
  delivery_zone text not null,
  notes text null,
  items jsonb not null default '[]'::jsonb,
  reward_ids text[] not null default '{}',
  order_total numeric(10,2) not null default 0,
  status text not null default 'pending' check (status in ('pending','preparing','ready','delivered','cancelled')),
  accounted_at timestamptz null,
  delivered_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists prelude_orders_created_at_idx on public.prelude_orders(created_at desc);
create index if not exists prelude_orders_status_idx on public.prelude_orders(status);
create index if not exists prelude_orders_customer_id_idx on public.prelude_orders(customer_id);

alter table public.prelude_orders enable row level security;
revoke all on table public.prelude_orders from anon;
revoke all on table public.prelude_orders from authenticated;

create or replace function public.create_prelude_order(
  input_customer_id uuid,
  input_customer_name text,
  input_customer_phone text,
  input_delivery_zone text,
  input_notes text,
  input_items jsonb,
  input_order_total numeric,
  input_reward_ids text[] default '{}'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id uuid;
  new_number text;
begin
  if coalesce(trim(input_customer_name),'')='' then raise exception 'El nombre es obligatorio.'; end if;
  if coalesce(trim(input_delivery_zone),'')='' then raise exception 'La zona de entrega es obligatoria.'; end if;
  if input_items is null or jsonb_typeof(input_items) <> 'array' or jsonb_array_length(input_items)=0 then raise exception 'El pedido está vacío.'; end if;
  if coalesce(input_order_total,0) < 0 then raise exception 'El total del pedido no es válido.'; end if;

  new_number := 'P-' || lpad(nextval('public.prelude_order_number_seq')::text, 5, '0');

  insert into public.prelude_orders(order_number,customer_id,customer_name,customer_phone,delivery_zone,notes,items,reward_ids,order_total)
  values(new_number,input_customer_id,trim(input_customer_name),nullif(trim(input_customer_phone),''),trim(input_delivery_zone),nullif(trim(input_notes),''),input_items,coalesce(input_reward_ids,'{}'),round(input_order_total,2))
  returning id into new_id;

  return jsonb_build_object('success',true,'id',new_id,'order_number',new_number);
end;
$$;

revoke all on function public.create_prelude_order(uuid,text,text,text,text,jsonb,numeric,text[]) from public;
grant execute on function public.create_prelude_order(uuid,text,text,text,text,jsonb,numeric,text[]) to anon;
grant execute on function public.create_prelude_order(uuid,text,text,text,text,jsonb,numeric,text[]) to authenticated;

create or replace function public.admin_list_prelude_orders()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare result jsonb;
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then raise exception 'No tienes permisos de administrador.'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',o.id,'order_number',o.order_number,'customer_id',o.customer_id,'customer_name',o.customer_name,'customer_phone',o.customer_phone,
    'delivery_zone',o.delivery_zone,'notes',o.notes,'items',o.items,'reward_ids',to_jsonb(o.reward_ids),'order_total',o.order_total,
    'status',o.status,'accounted_at',o.accounted_at,'delivered_at',o.delivered_at,'created_at',o.created_at,'updated_at',o.updated_at
  ) order by o.created_at desc),'[]'::jsonb) into result from public.prelude_orders o;
  return result;
end;
$$;
revoke all on function public.admin_list_prelude_orders() from public;
grant execute on function public.admin_list_prelude_orders() to authenticated;

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
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then raise exception 'No tienes permisos de administrador.'; end if;
  if input_status not in ('pending','preparing','ready','delivered','cancelled') then raise exception 'Estado no válido.'; end if;
  select * into o from public.prelude_orders where id=input_order_id for update;
  if not found then raise exception 'Pedido no encontrado.'; end if;

  update public.prelude_orders set status=input_status,updated_at=now(),delivered_at=case when input_status='delivered' then coalesce(delivered_at,now()) else delivered_at end where id=input_order_id;

  -- Al entregar un pedido registrado, incorporamos sus perfumes a Mi Colección Prelude y contabilizamos la compra una única vez.
  if input_status='delivered' and o.customer_id is not null and o.accounted_at is null then
    for item in select value from jsonb_array_elements(o.items)
    loop
      perfume_name := nullif(trim(item->>'name'),'');
      if perfume_name is not null then
        insert into public.prelude_customer_library(customer_id,perfume,source_code)
        values(o.customer_id,perfume_name,'ORDER-'||o.order_number)
        on conflict (customer_id,perfume) do nothing;
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
