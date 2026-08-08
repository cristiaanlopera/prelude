-- Prelude Studio · Fase 3 · Clientes + Mi Colección Prelude
-- Ejecutar una sola vez en Supabase SQL Editor.

create or replace function public.admin_get_customer_orders(input_customer_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare result jsonb;
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then
    raise exception 'No tienes permisos de administrador.';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',o.id,'order_number',o.order_number,'delivery_zone',o.delivery_zone,
    'items',o.items,'order_total',o.order_total,'status',o.status,
    'created_at',o.created_at,'updated_at',o.updated_at,'delivered_at',o.delivered_at
  ) order by o.created_at desc),'[]'::jsonb)
  into result
  from public.prelude_orders o where o.customer_id=input_customer_id;
  return result;
end;
$$;
revoke all on function public.admin_get_customer_orders(uuid) from public;
grant execute on function public.admin_get_customer_orders(uuid) to authenticated;

create or replace function public.admin_set_customer_artwork(
  input_customer_id uuid,
  input_perfume text,
  input_unlocked boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare changed integer;
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then
    raise exception 'No tienes permisos de administrador.';
  end if;
  if not exists(select 1 from public.prelude_customers where id=input_customer_id) then
    raise exception 'Cliente no encontrado.';
  end if;
  if nullif(trim(input_perfume),'') is null then raise exception 'Perfume no válido.'; end if;

  if input_unlocked then
    insert into public.prelude_customer_library(customer_id,perfume,source_code)
    values(input_customer_id,trim(input_perfume),'MANUAL-STUDIO')
    on conflict (customer_id,perfume) do update set source_code=coalesce(public.prelude_customer_library.source_code,'MANUAL-STUDIO');
    get diagnostics changed=row_count;
    -- El desbloqueo manual también puede mostrarse como nueva obra la próxima vez que el cliente entre.
    if not exists(select 1 from public.prelude_artwork_notifications n where n.customer_id=input_customer_id and n.perfume=trim(input_perfume) and n.seen_at is null) then
      insert into public.prelude_artwork_notifications(customer_id,perfume,order_number)
      values(input_customer_id,trim(input_perfume),'MANUAL');
    end if;
  else
    delete from public.prelude_customer_library where customer_id=input_customer_id and perfume=trim(input_perfume);
    get diagnostics changed=row_count;
    delete from public.prelude_artwork_notifications where customer_id=input_customer_id and perfume=trim(input_perfume) and seen_at is null;
  end if;
  return jsonb_build_object('success',true,'customer_id',input_customer_id,'perfume',trim(input_perfume),'unlocked',input_unlocked,'changed',changed);
end;
$$;
revoke all on function public.admin_set_customer_artwork(uuid,text,boolean) from public;
grant execute on function public.admin_set_customer_artwork(uuid,text,boolean) to authenticated;
