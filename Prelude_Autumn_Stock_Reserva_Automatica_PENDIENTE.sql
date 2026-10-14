-- PRELUDE · AUTUMN DISCOVERY SET · RESERVA AUTOMÁTICA DE ML
-- Fecha: 2026-10-14.
-- PROPUESTA PARA REVISIÓN. NO EJECUTADA EN LA BASE DE DATOS REAL.
-- No limita el número de sets. Cada compra reserva 3 ml por referencia.
-- Exige tener configurado el stock real por perfume; no inventa cifras.
-- Depende de la migración Prelude_Autumn_2026_Oferta_Controlada_PENDIENTE.sql,
-- de los campos documentados en los SQL del paquete y de su verificación en producción.
-- Conserva la semántica del stock inicial; no lo reduce dos veces.
BEGIN;


-- Reserva SOLO los ml de Autumn de pedidos pendientes/en preparación/listos.
-- Al entregar, la reserva deja de contarse y pasa a contar la venta entregada
-- mediante la lógica histórica. Si se cancela, la reserva desaparece.
CREATE OR REPLACE FUNCTION public.prelude_autumn_ml_reserved(input_catalog_id uuid)
RETURNS numeric
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path=public,pg_temp
AS $$
  SELECT COALESCE(SUM(3), 0)
  FROM public.prelude_orders AS o
  CROSS JOIN LATERAL jsonb_array_elements(o.items) AS i(item)
  WHERE o.status IN ('pending', 'preparing', 'ready')
    AND i.item->>'set_id' = 'autumn-2026'
    AND i.item->>'catalog_id' = input_catalog_id::text
    AND i.item->>'size' = '3 ml'
    AND i.item->>'qty' = '1';
$$;
REVOKE ALL ON FUNCTION public.prelude_autumn_ml_reserved(uuid) FROM PUBLIC,anon,authenticated;

-- Modifica la vista pública de stock (sin alterar el resto del catálogo).
create or replace function public.get_prelude_catalog()
returns jsonb language sql security definer set search_path=public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'name',c.name,'brand',c.brand,'active',c.active,
    'availability_status',case when c.deleted_at is null then c.availability_status else 'hidden' end,
    'display_order',c.display_order,
    'price_2ml',c.price_2ml,'price_3ml',c.price_3ml,'price_5ml',c.price_5ml,'price_10ml',c.price_10ml,
    'image_url',c.image_url,'description',c.description,'accords',to_jsonb(c.accords),'notes',to_jsonb(c.notes),
    'journey_theme',c.journey_theme,'journey_title',c.journey_title,'journey_copy',c.journey_copy,
    'low_stock_threshold_ml',c.low_stock_threshold_ml,
    'stock_available_ml',case
      when c.stock_initial_ml is null then null
      else greatest(0,c.stock_initial_ml-coalesce(s.sold_ml,0)-public.prelude_autumn_ml_reserved(c.id))
    end
  ) order by
    case when c.deleted_at is not null then 4 when c.availability_status='upcoming' then 0 when c.availability_status='published' then 1 when c.availability_status='soldout' then 2 else 3 end,
    c.display_order,c.created_at,c.name),'[]'::jsonb)
  from public.prelude_catalog c
  left join lateral (
    select sum(
      coalesce(nullif(regexp_replace(item->>'size','[^0-9.]','','g'),'')::numeric,0)
      * coalesce(nullif(item->>'qty','')::numeric,1)
    ) as sold_ml
    from public.prelude_orders o
    cross join lateral jsonb_array_elements(o.items) item
    where o.status='delivered' and trim(item->>'name')=c.name
  ) s on true;
$$;
revoke all on function public.get_prelude_catalog() from public;
grant execute on function public.get_prelude_catalog() to anon,authenticated;

-- Modifica la vista de stock de Studio.
create or replace function public.admin_list_prelude_catalog()
returns jsonb language plpgsql security definer set search_path=public as $$
declare result jsonb;
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then
    raise exception 'No tienes permisos de administrador.';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'name',c.name,'brand',c.brand,'active',c.active,
    'availability_status',c.availability_status,'display_order',c.display_order,'deleted_at',c.deleted_at,
    'price_2ml',c.price_2ml,'price_3ml',c.price_3ml,'price_5ml',c.price_5ml,'price_10ml',c.price_10ml,
    'image_url',c.image_url,'stock_initial_ml',c.stock_initial_ml,'low_stock_threshold_ml',c.low_stock_threshold_ml,
    'sold_ml',coalesce(s.sold_ml,0),
    'stock_available_ml',case when c.stock_initial_ml is null then null else greatest(0,c.stock_initial_ml-coalesce(s.sold_ml,0)-public.prelude_autumn_ml_reserved(c.id)) end
  ) order by case when c.availability_status='upcoming' then 0 when c.availability_status='published' then 1 when c.availability_status='soldout' then 2 else 3 end,c.display_order,c.name),'[]'::jsonb)
  into result
  from public.prelude_catalog c
  left join lateral (
    select sum(
      coalesce(nullif(regexp_replace(item->>'size','[^0-9.]','','g'),'')::numeric,0)
      * coalesce(nullif(item->>'qty','')::numeric,1)
    ) as sold_ml
    from public.prelude_orders o
    cross join lateral jsonb_array_elements(o.items) item
    where o.status='delivered' and trim(item->>'name')=c.name
  ) s on true
  where c.deleted_at is null;
  return result;
end;$$;
revoke all on function public.admin_list_prelude_catalog() from public;
grant execute on function public.admin_list_prelude_catalog() to authenticated;

-- Cuando Studio ajusta 'disponible', el stock inicial se reconstruye
-- contando las ventas entregadas Y las reservas de Autumn.
create or replace function public.admin_set_prelude_catalog_stock(input_catalog_id uuid,input_available_ml numeric,input_low_stock_threshold_ml numeric)
returns jsonb language plpgsql security definer set search_path=public as $$
declare sold numeric:=0;
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then raise exception 'No tienes permisos de administrador.'; end if;
  if input_available_ml<0 or input_low_stock_threshold_ml<0 then raise exception 'Valores de stock no válidos.'; end if;
  select coalesce(sum(coalesce(nullif(regexp_replace(item->>'size','[^0-9.]','','g'),'')::numeric,0)*coalesce(nullif(item->>'qty','')::numeric,1)),0) into sold
  from public.prelude_orders o cross join lateral jsonb_array_elements(o.items) item
  where o.status='delivered' and trim(item->>'name')=(select name from public.prelude_catalog where id=input_catalog_id);
  update public.prelude_catalog set stock_initial_ml=round(input_available_ml+sold+public.prelude_autumn_ml_reserved(input_catalog_id),2),low_stock_threshold_ml=round(input_low_stock_threshold_ml,2),updated_at=now() where id=input_catalog_id;
  if not found then raise exception 'Perfume no encontrado.'; end if;
  return jsonb_build_object('success',true,'id',input_catalog_id,'available_ml',input_available_ml,'sold_ml',sold,'reserved_autumn_ml',public.prelude_autumn_ml_reserved(input_catalog_id));
end;$$;
revoke all on function public.admin_set_prelude_catalog_stock(uuid,numeric,numeric) from public;
grant execute on function public.admin_set_prelude_catalog_stock(uuid,numeric,numeric) to authenticated;

COMMIT;

-- PRUEBA SOLO LECTURA:
-- select public.prelude_autumn_ml_reserved('22d3ba81-eab3-4f6b-ab8a-a6de229cd8db');
-- select public.get_prelude_catalog();
-- select public.admin_list_prelude_catalog(); -- requiere usuario autenticado administrador
