-- ============================================================
-- PRELUDE · FIX CATÁLOGO
-- Storage unificado + borrado lógico consistente en Studio
-- Ejecutar UNA VEZ en Supabase SQL Editor
-- ============================================================

begin;

-- 1) Asegurar el bucket canónico usado por la reconstrucción.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values(
  'prelude-media','prelude-media',true,10485760,
  array['image/jpeg','image/png','image/webp','image/avif']::text[]
)
on conflict(id) do update set
  public=true,
  file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

-- 2) Studio debe excluir del listado los perfumes ya eliminados.
create or replace function public.admin_list_prelude_catalog()
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare result jsonb;
begin
  if not public.is_prelude_admin() then
    raise exception 'PRELUDE_ADMIN_REQUIRED';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id',c.id,
        'name',c.name,
        'brand',c.brand,
        'active',c.active,
        'availability_status',c.availability_status,
        'display_order',c.display_order,
        'price_2ml',c.price_2ml,
        'price_3ml',c.price_3ml,
        'price_5ml',c.price_5ml,
        'price_10ml',c.price_10ml,
        'image_url',c.image_url,
        'stock_initial_ml',c.stock_initial_ml,
        'low_stock_threshold_ml',c.low_stock_threshold_ml,
        'sold_ml',coalesce(s.sold_ml,0),
        'stock_available_ml',case
          when c.stock_initial_ml is null then null
          else greatest(0,c.stock_initial_ml-coalesce(s.sold_ml,0))
        end
      )
      order by
        case c.availability_status
          when 'upcoming' then 0
          when 'published' then 1
          else 2
        end,
        c.display_order,
        c.name
    ),
    '[]'::jsonb
  ) into result
  from public.prelude_catalog c
  left join lateral (
    select sum(
      coalesce(nullif(regexp_replace(item->>'size','[^0-9.]','','g'),'')::numeric,0)
      * coalesce(nullif(item->>'qty','')::numeric,1)
    ) as sold_ml
    from public.prelude_orders o
    cross join lateral jsonb_array_elements(o.items) item
    where o.status='delivered'
      and lower(trim(item->>'name'))=lower(trim(c.name))
  ) s on true
  where c.deleted_at is null;

  return result;
end;
$$;

revoke all on function public.admin_list_prelude_catalog() from public;
grant execute on function public.admin_list_prelude_catalog() to authenticated;

-- 3) Borrado lógico idempotente.
-- Si Studio conserva una tarjeta antigua en memoria y se pulsa de nuevo,
-- devuelve éxito en lugar de PRELUDE_CATALOG_PRODUCT_NOT_FOUND.
create or replace function public.admin_delete_prelude_catalog_product(
  input_catalog_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_name text;
  v_deleted_at timestamptz;
begin
  if not public.is_prelude_admin() then
    raise exception 'PRELUDE_ADMIN_REQUIRED';
  end if;

  select name,deleted_at
  into v_name,v_deleted_at
  from public.prelude_catalog
  where id=input_catalog_id;

  if not found then
    raise exception 'PRELUDE_CATALOG_PRODUCT_NOT_FOUND';
  end if;

  if v_deleted_at is null then
    update public.prelude_catalog
    set
      deleted_at=now(),
      availability_status='hidden',
      active=false,
      updated_at=now()
    where id=input_catalog_id;
  end if;

  update public.prelude_museum_works
  set published=false,
      updated_at=now()
  where catalog_id=input_catalog_id
     or lower(trim(perfume_name))=lower(trim(v_name));

  return jsonb_build_object(
    'success',true,
    'id',input_catalog_id,
    'name',v_name,
    'already_deleted',(v_deleted_at is not null),
    'message','Perfume eliminado correctamente.'
  );
end;
$$;

revoke all on function public.admin_delete_prelude_catalog_product(uuid) from public;
grant execute on function public.admin_delete_prelude_catalog_product(uuid) to authenticated;

commit;

select
  'CATALOGO_FIX_OK' as estado,
  exists(select 1 from storage.buckets where id='prelude-media') as bucket_ok,
  exists(
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='admin_delete_prelude_catalog_product'
  ) as delete_rpc_ok,
  exists(
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='admin_list_prelude_catalog'
  ) as list_rpc_ok;
