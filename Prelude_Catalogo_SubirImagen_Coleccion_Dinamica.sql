-- PRELUDE · CATÁLOGO: SUBIR IMAGEN + PRÓXIMAMENTE SIN PRECIOS + COLECCIÓN DINÁMICA
-- Ejecutar UNA VEZ en Supabase → SQL Editor.

-- 1) Permitir perfumes "Próximamente" sin precios todavía.
alter table public.prelude_catalog alter column price_2ml drop not null;
alter table public.prelude_catalog alter column price_3ml drop not null;
alter table public.prelude_catalog alter column price_5ml drop not null;
alter table public.prelude_catalog alter column price_10ml drop not null;

-- Sustituimos los checks antiguos por checks que aceptan NULL, pero nunca precios <= 0.
do $$ begin alter table public.prelude_catalog drop constraint if exists prelude_catalog_price_2ml_check; exception when undefined_object then null; end $$;
do $$ begin alter table public.prelude_catalog drop constraint if exists prelude_catalog_price_3ml_check; exception when undefined_object then null; end $$;
do $$ begin alter table public.prelude_catalog drop constraint if exists prelude_catalog_price_5ml_check; exception when undefined_object then null; end $$;
do $$ begin alter table public.prelude_catalog drop constraint if exists prelude_catalog_price_10ml_check; exception when undefined_object then null; end $$;

do $$ begin
  alter table public.prelude_catalog add constraint prelude_catalog_price_2ml_check check(price_2ml is null or price_2ml>0);
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.prelude_catalog add constraint prelude_catalog_price_3ml_check check(price_3ml is null or price_3ml>0);
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.prelude_catalog add constraint prelude_catalog_price_5ml_check check(price_5ml is null or price_5ml>0);
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.prelude_catalog add constraint prelude_catalog_price_10ml_check check(price_10ml is null or price_10ml>0);
exception when duplicate_object then null; end $$;

-- 2) Bucket público para imágenes del catálogo. La lectura es pública; solo admins pueden escribir.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('catalog-images','catalog-images',true,8388608,array['image/jpeg','image/png','image/webp','image/avif'])
on conflict(id) do update set public=true,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "Prelude admins upload catalog images" on storage.objects;
create policy "Prelude admins upload catalog images" on storage.objects
for insert to authenticated
with check (bucket_id='catalog-images' and exists(select 1 from public.prelude_admins where user_id=auth.uid()));

drop policy if exists "Prelude admins update catalog images" on storage.objects;
create policy "Prelude admins update catalog images" on storage.objects
for update to authenticated
using (bucket_id='catalog-images' and exists(select 1 from public.prelude_admins where user_id=auth.uid()))
with check (bucket_id='catalog-images' and exists(select 1 from public.prelude_admins where user_id=auth.uid()));

drop policy if exists "Prelude admins delete catalog images" on storage.objects;
create policy "Prelude admins delete catalog images" on storage.objects
for delete to authenticated
using (bucket_id='catalog-images' and exists(select 1 from public.prelude_admins where user_id=auth.uid()));

-- 3) Crear perfume con estado desde el principio. Próximamente/oculto pueden no tener precios.
create or replace function public.admin_create_prelude_catalog_product(
  input_name text,
  input_brand text,
  input_image_url text,
  input_price_2ml numeric,
  input_price_3ml numeric,
  input_price_5ml numeric,
  input_price_10ml numeric,
  input_status text default 'upcoming'
)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  new_id uuid;
  normalized text:=lower(trim(coalesce(input_status,'upcoming')));
  p2 numeric:=input_price_2ml; p3 numeric:=input_price_3ml; p5 numeric:=input_price_5ml; p10 numeric:=input_price_10ml;
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then raise exception 'No tienes permisos de administrador.'; end if;
  if nullif(trim(input_name),'') is null or nullif(trim(input_brand),'') is null then raise exception 'Nombre y marca son obligatorios.'; end if;
  if normalized not in ('published','upcoming','hidden') then raise exception 'Estado de catálogo no válido.'; end if;
  if normalized='published' and (p2 is null or p3 is null or p5 is null or p10 is null or least(p2,p3,p5,p10)<=0) then
    raise exception 'Para publicar el perfume debes completar los precios de 2, 3, 5 y 10 ml.';
  end if;
  if coalesce(p2,1)<=0 or coalesce(p3,1)<=0 or coalesce(p5,1)<=0 or coalesce(p10,1)<=0 then raise exception 'Los precios, cuando se indiquen, deben ser superiores a 0.'; end if;

  insert into public.prelude_catalog(name,brand,image_url,price_2ml,price_3ml,price_5ml,price_10ml,active,availability_status)
  values(trim(input_name),trim(input_brand),nullif(trim(coalesce(input_image_url,'')),''),
         case when p2 is null then null else round(p2,2) end,
         case when p3 is null then null else round(p3,2) end,
         case when p5 is null then null else round(p5,2) end,
         case when p10 is null then null else round(p10,2) end,
         normalized<>'hidden',normalized)
  returning id into new_id;

  -- Toda incorporación crea inmediatamente su ficha en el Museo/Colección.
  insert into public.prelude_museum_works(perfume_name,brand,artwork_path,description,published,updated_at)
  values(trim(input_name),trim(input_brand),'','',false,now())
  on conflict(perfume_name) do update set brand=excluded.brand,updated_at=now();

  return jsonb_build_object('success',true,'id',new_id,'availability_status',normalized);
exception when unique_violation then raise exception 'Ya existe un perfume con ese nombre.';
end;$$;
revoke all on function public.admin_create_prelude_catalog_product(text,text,text,numeric,numeric,numeric,numeric,text) from public;
grant execute on function public.admin_create_prelude_catalog_product(text,text,text,numeric,numeric,numeric,numeric,text) to authenticated;

-- 4) Publicar exige precios completos. Así no se puede poner a la venta por accidente sin precio.
create or replace function public.admin_set_prelude_catalog_status(input_catalog_id uuid,input_status text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare normalized text:=lower(trim(coalesce(input_status,''))); rowdata public.prelude_catalog%rowtype;
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then raise exception 'No tienes permisos de administrador.'; end if;
  if normalized not in ('published','upcoming','hidden') then raise exception 'Estado de catálogo no válido.'; end if;
  select * into rowdata from public.prelude_catalog where id=input_catalog_id and deleted_at is null;
  if rowdata.id is null then raise exception 'Perfume no encontrado.'; end if;
  if normalized='published' and (rowdata.price_2ml is null or rowdata.price_3ml is null or rowdata.price_5ml is null or rowdata.price_10ml is null) then
    raise exception 'Antes de publicar, completa los precios de 2, 3, 5 y 10 ml.';
  end if;
  update public.prelude_catalog set availability_status=normalized,active=(normalized<>'hidden'),updated_at=now() where id=input_catalog_id;
  return jsonb_build_object('success',true,'id',input_catalog_id,'availability_status',normalized);
end;$$;
revoke all on function public.admin_set_prelude_catalog_status(uuid,text) from public;
grant execute on function public.admin_set_prelude_catalog_status(uuid,text) to authenticated;

-- 5) Precios: siguen exigiéndose los cuatro cuando se guardan.
create or replace function public.admin_update_prelude_catalog_prices(input_catalog_id uuid,input_price_2ml numeric,input_price_3ml numeric,input_price_5ml numeric,input_price_10ml numeric)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then raise exception 'No tienes permisos de administrador.'; end if;
  if input_price_2ml is null or input_price_3ml is null or input_price_5ml is null or input_price_10ml is null or least(input_price_2ml,input_price_3ml,input_price_5ml,input_price_10ml)<=0 then raise exception 'Completa los cuatro precios con valores superiores a 0.'; end if;
  update public.prelude_catalog set price_2ml=round(input_price_2ml,2),price_3ml=round(input_price_3ml,2),price_5ml=round(input_price_5ml,2),price_10ml=round(input_price_10ml,2),updated_at=now() where id=input_catalog_id and deleted_at is null;
  if not found then raise exception 'Perfume no encontrado.'; end if;
  return jsonb_build_object('success',true,'id',input_catalog_id);
end;$$;

-- 6) Cambiar imagen desde Studio.
create or replace function public.admin_update_prelude_catalog_image(input_catalog_id uuid,input_image_url text)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then raise exception 'No tienes permisos de administrador.'; end if;
  update public.prelude_catalog set image_url=nullif(trim(coalesce(input_image_url,'')),''),updated_at=now() where id=input_catalog_id and deleted_at is null;
  if not found then raise exception 'Perfume no encontrado.'; end if;
  return jsonb_build_object('success',true,'id',input_catalog_id,'image_url',nullif(trim(coalesce(input_image_url,'')),''));
end;$$;
revoke all on function public.admin_update_prelude_catalog_image(uuid,text) from public;
grant execute on function public.admin_update_prelude_catalog_image(uuid,text) to authenticated;

-- 7) Listado del Museo desde Supabase para que cada perfume nuevo aumente automáticamente el total de obras.
create or replace function public.get_prelude_museum_works()
returns jsonb language sql security definer set search_path=public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'perfume_name',m.perfume_name,'brand',m.brand,'artwork_path',m.artwork_path,'description',m.description,'published',m.published
  ) order by m.perfume_name),'[]'::jsonb) from public.prelude_museum_works m;
$$;
revoke all on function public.get_prelude_museum_works() from public;
grant execute on function public.get_prelude_museum_works() to anon,authenticated;
