-- PRELUDE · STOCK REAL EN CATÁLOGO + ESTADO AGOTADO
-- Ejecutar UNA VEZ en Supabase -> SQL Editor -> New query -> Run.
-- Compatible con la estructura actual de Prelude Studio.

-- 1) Añadir "soldout" como estado válido del catálogo.
alter table public.prelude_catalog
  drop constraint if exists prelude_catalog_availability_status_check;

alter table public.prelude_catalog
  add constraint prelude_catalog_availability_status_check
  check (availability_status in ('published','upcoming','soldout','hidden'));

-- 2) El catálogo público recibe stock disponible y umbral de stock bajo.
--    El stock disponible se calcula igual que en Prelude Studio:
--    stock inicial - ml de pedidos entregados.
create or replace function public.get_prelude_catalog()
returns jsonb
language sql
security definer
set search_path=public
as $$
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
        'description',c.description,
        'accords',to_jsonb(c.accords),
        'notes',to_jsonb(c.notes),
        'journey_theme',c.journey_theme,
        'journey_title',c.journey_title,
        'journey_copy',c.journey_copy,
        'low_stock_threshold_ml',c.low_stock_threshold_ml,
        'stock_available_ml',case
          when c.stock_initial_ml is null then null
          else greatest(0,c.stock_initial_ml-coalesce(s.sold_ml,0))
        end,
        'created_at',c.created_at,
        'updated_at',c.updated_at
      )
      order by
        case
          when c.availability_status='upcoming' then 0
          when c.availability_status='published' then 1
          when c.availability_status='soldout' then 2
          else 3
        end,
        c.display_order,c.created_at,c.name
    ),
    '[]'::jsonb
  )
  from public.prelude_catalog c
  left join lateral (
    select sum(
      coalesce(nullif(regexp_replace(item->>'size','[^0-9.]','','g'),'')::numeric,0)
      * coalesce(nullif(item->>'qty','')::numeric,1)
    ) as sold_ml
    from public.prelude_orders o
    cross join lateral jsonb_array_elements(o.items) item
    where o.status='delivered'
      and trim(item->>'name')=c.name
  ) s on true;
$$;

revoke all on function public.get_prelude_catalog() from public;
grant execute on function public.get_prelude_catalog() to anon,authenticated;

-- 3) Studio permite seleccionar manualmente "Agotado".
create or replace function public.admin_set_prelude_catalog_status(
  input_catalog_id uuid,
  input_status text
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare normalized text:=lower(trim(coalesce(input_status,'')));
begin
  if auth.uid() is null or not exists(
    select 1 from public.prelude_admins where user_id=auth.uid()
  ) then
    raise exception 'No tienes permisos de administrador.';
  end if;

  if normalized not in ('published','upcoming','soldout','hidden') then
    raise exception 'Estado de catálogo no válido.';
  end if;

  update public.prelude_catalog
  set availability_status=normalized,
      active=(normalized<>'hidden'),
      updated_at=now()
  where id=input_catalog_id;

  if not found then raise exception 'Perfume no encontrado.'; end if;

  return jsonb_build_object(
    'success',true,
    'id',input_catalog_id,
    'availability_status',normalized
  );
end;
$$;

revoke all on function public.admin_set_prelude_catalog_status(uuid,text) from public;
grant execute on function public.admin_set_prelude_catalog_status(uuid,text) to authenticated;
