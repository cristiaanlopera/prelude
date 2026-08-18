-- PRELUDE · ESTADOS DE STOCK EN CATÁLOGO
-- Ejecutar UNA VEZ en Supabase > SQL Editor > New query > Run.
-- Añade el estado manual "Agotado" y expone el stock al catálogo público.

alter table public.prelude_catalog drop constraint if exists prelude_catalog_availability_status_check;
alter table public.prelude_catalog
  add constraint prelude_catalog_availability_status_check
  check (availability_status in ('published','upcoming','soldout','hidden'));

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
      else greatest(0,c.stock_initial_ml-coalesce(s.sold_ml,0))
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

create or replace function public.admin_set_prelude_catalog_status(input_catalog_id uuid,input_status text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare normalized text:=lower(trim(coalesce(input_status,'')));
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then
    raise exception 'No tienes permisos de administrador.';
  end if;
  if normalized not in ('published','upcoming','soldout','hidden') then
    raise exception 'Estado no válido.';
  end if;
  update public.prelude_catalog
  set availability_status=normalized,
      active=(normalized<>'hidden'),
      updated_at=now()
  where id=input_catalog_id and deleted_at is null;
  if not found then raise exception 'Perfume no encontrado.'; end if;
  return jsonb_build_object('success',true,'id',input_catalog_id,'availability_status',normalized);
end;$$;
revoke all on function public.admin_set_prelude_catalog_status(uuid,text) from public;
grant execute on function public.admin_set_prelude_catalog_status(uuid,text) to authenticated;

-- Mantiene la lista de Studio completa y con el stock calculado.
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
    'stock_available_ml',case when c.stock_initial_ml is null then null else greatest(0,c.stock_initial_ml-coalesce(s.sold_ml,0)) end
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
