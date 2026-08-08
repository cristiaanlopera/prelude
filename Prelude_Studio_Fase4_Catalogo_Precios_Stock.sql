-- PRELUDE STUDIO · FASE 4 — CATÁLOGO, PRECIOS Y STOCK
-- Ejecutar UNA VEZ en Supabase → SQL Editor → New query → Run.
-- Es acumulativo sobre las fases anteriores.

create table if not exists public.prelude_catalog (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  brand text not null,
  active boolean not null default true,
  price_2ml numeric(10,2) not null check(price_2ml>0),
  price_3ml numeric(10,2) not null check(price_3ml>0),
  price_5ml numeric(10,2) not null check(price_5ml>0),
  price_10ml numeric(10,2) not null check(price_10ml>0),
  image_url text null,
  description text null,
  accords text[] not null default '{}',
  notes text[] not null default '{}',
  journey_theme text null,
  journey_title text null,
  journey_copy text null,
  stock_initial_ml numeric(10,2) null check(stock_initial_ml is null or stock_initial_ml>=0),
  low_stock_threshold_ml numeric(10,2) not null default 15 check(low_stock_threshold_ml>=0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists prelude_catalog_active_idx on public.prelude_catalog(active,name);
alter table public.prelude_catalog enable row level security;
revoke all on table public.prelude_catalog from anon;
revoke all on table public.prelude_catalog from authenticated;

-- Semilla de las 23 fragancias actuales. ON CONFLICT DO NOTHING evita sobrescribir cambios posteriores hechos desde Studio.
insert into public.prelude_catalog(name,brand,price_2ml,price_3ml,price_5ml,price_10ml,active) values
  ('Le Sel d''Issey','Issey Miyake',3.33,4.23,6.1,10.69,true),
  ('Amber Oud Gold Edition','Al Haramain',2.89,3.56,4.99,8.46,true),
  ('Dior Homme Intense','Dior',4.14,5.45,8.13,14.75,true),
  ('Mercedes-Benz Club Black','Mercedes-Benz',3.36,4.27,6.16,10.81,true),
  ('CK One','Calvin Klein',1.92,2.1,2.56,3.6,true),
  ('La Nuit de L''Homme','Yves Saint Laurent',2.51,2.99,4.03,6.55,true),
  ('Club de Nuit Sillage','Armaf',2.62,3.16,4.32,7.13,true),
  ('Détour Noir','Al Haramain',2.19,2.52,3.25,4.99,true),
  ('Fico di Amalfi','Acqua di Parma',3.85,5.0,7.38,13.25,true),
  ('Eros','Versace',2.63,3.18,4.35,7.19,true),
  ('Bois Impérial','Essential Parfums',3.06,3.82,5.41,9.32,true),
  ('Bal d''Afrique','Byredo',8.54,12.03,19.11,36.7,true),
  ('Le Rem','Réminiscence',3.53,4.53,6.6,11.69,true),
  ('Le Beau','Jean Paul Gaultier',3.14,3.93,5.61,9.7,true),
  ('Stronger With You','Giorgio Armani',3.3,4.18,6.01,10.51,true),
  ('Torino 21','Xerjoff',6.88,9.55,14.96,28.41,true),
  ('First Instinct','Abercrombie & Fitch',2.53,3.03,4.1,6.69,true),
  ('Egeo Bomb Black','O Boticário',2.87,3.53,4.93,8.36,true),
  ('Armani Code','Giorgio Armani',2.49,2.96,3.99,6.46,true),
  ('Starwalker','Montblanc',2.64,3.19,4.37,7.22,true),
  ('Nautica Voyage','Nautica',2.05,2.3,2.88,4.26,true),
  ('Cool Water','Davidoff',1.93,2.13,2.6,3.7,true),
  ('Sauvage','Dior',2.25,2.61,3.39,5.27,true)
on conflict (name) do nothing;

create or replace function public.get_prelude_catalog()
returns jsonb language sql security definer set search_path=public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'name',c.name,'brand',c.brand,'active',c.active,
    'price_2ml',c.price_2ml,'price_3ml',c.price_3ml,'price_5ml',c.price_5ml,'price_10ml',c.price_10ml,
    'image_url',c.image_url,'description',c.description,'accords',to_jsonb(c.accords),'notes',to_jsonb(c.notes),
    'journey_theme',c.journey_theme,'journey_title',c.journey_title,'journey_copy',c.journey_copy
  ) order by c.created_at,c.name),'[]'::jsonb) from public.prelude_catalog c;
$$;
revoke all on function public.get_prelude_catalog() from public;
grant execute on function public.get_prelude_catalog() to anon,authenticated;

create or replace function public.admin_list_prelude_catalog()
returns jsonb language plpgsql security definer set search_path=public as $$
declare result jsonb;
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then raise exception 'No tienes permisos de administrador.'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'name',c.name,'brand',c.brand,'active',c.active,
    'price_2ml',c.price_2ml,'price_3ml',c.price_3ml,'price_5ml',c.price_5ml,'price_10ml',c.price_10ml,
    'image_url',c.image_url,'stock_initial_ml',c.stock_initial_ml,'low_stock_threshold_ml',c.low_stock_threshold_ml,
    'sold_ml',coalesce(s.sold_ml,0),
    'stock_available_ml',case when c.stock_initial_ml is null then null else greatest(0,c.stock_initial_ml-coalesce(s.sold_ml,0)) end
  ) order by c.name),'[]'::jsonb) into result
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
  return result;
end;$$;
revoke all on function public.admin_list_prelude_catalog() from public;
grant execute on function public.admin_list_prelude_catalog() to authenticated;

create or replace function public.admin_set_prelude_catalog_active(input_catalog_id uuid,input_active boolean)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then raise exception 'No tienes permisos de administrador.'; end if;
  update public.prelude_catalog set active=input_active,updated_at=now() where id=input_catalog_id;
  if not found then raise exception 'Perfume no encontrado.'; end if;
  return jsonb_build_object('success',true,'id',input_catalog_id,'active',input_active);
end;$$;
revoke all on function public.admin_set_prelude_catalog_active(uuid,boolean) from public;
grant execute on function public.admin_set_prelude_catalog_active(uuid,boolean) to authenticated;

create or replace function public.admin_update_prelude_catalog_prices(input_catalog_id uuid,input_price_2ml numeric,input_price_3ml numeric,input_price_5ml numeric,input_price_10ml numeric)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then raise exception 'No tienes permisos de administrador.'; end if;
  if least(input_price_2ml,input_price_3ml,input_price_5ml,input_price_10ml)<=0 then raise exception 'Los precios deben ser superiores a 0.'; end if;
  update public.prelude_catalog set price_2ml=round(input_price_2ml,2),price_3ml=round(input_price_3ml,2),price_5ml=round(input_price_5ml,2),price_10ml=round(input_price_10ml,2),updated_at=now() where id=input_catalog_id;
  if not found then raise exception 'Perfume no encontrado.'; end if;
  return jsonb_build_object('success',true,'id',input_catalog_id);
end;$$;
revoke all on function public.admin_update_prelude_catalog_prices(uuid,numeric,numeric,numeric,numeric) from public;
grant execute on function public.admin_update_prelude_catalog_prices(uuid,numeric,numeric,numeric,numeric) to authenticated;

create or replace function public.admin_set_prelude_catalog_stock(input_catalog_id uuid,input_available_ml numeric,input_low_stock_threshold_ml numeric)
returns jsonb language plpgsql security definer set search_path=public as $$
declare sold numeric:=0;
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then raise exception 'No tienes permisos de administrador.'; end if;
  if input_available_ml<0 or input_low_stock_threshold_ml<0 then raise exception 'Valores de stock no válidos.'; end if;
  select coalesce(sum(coalesce(nullif(regexp_replace(item->>'size','[^0-9.]','','g'),'')::numeric,0)*coalesce(nullif(item->>'qty','')::numeric,1)),0) into sold
  from public.prelude_orders o cross join lateral jsonb_array_elements(o.items) item
  where o.status='delivered' and trim(item->>'name')=(select name from public.prelude_catalog where id=input_catalog_id);
  update public.prelude_catalog set stock_initial_ml=round(input_available_ml+sold,2),low_stock_threshold_ml=round(input_low_stock_threshold_ml,2),updated_at=now() where id=input_catalog_id;
  if not found then raise exception 'Perfume no encontrado.'; end if;
  return jsonb_build_object('success',true,'id',input_catalog_id,'available_ml',input_available_ml,'sold_ml',sold);
end;$$;
revoke all on function public.admin_set_prelude_catalog_stock(uuid,numeric,numeric) from public;
grant execute on function public.admin_set_prelude_catalog_stock(uuid,numeric,numeric) to authenticated;

create or replace function public.admin_create_prelude_catalog_product(input_name text,input_brand text,input_image_url text,input_price_2ml numeric,input_price_3ml numeric,input_price_5ml numeric,input_price_10ml numeric)
returns jsonb language plpgsql security definer set search_path=public as $$
declare new_id uuid; publish_now boolean;
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then raise exception 'No tienes permisos de administrador.'; end if;
  if nullif(trim(input_name),'') is null or nullif(trim(input_brand),'') is null then raise exception 'Nombre y marca son obligatorios.'; end if;
  if least(input_price_2ml,input_price_3ml,input_price_5ml,input_price_10ml)<=0 then raise exception 'Los precios deben ser superiores a 0.'; end if;
  publish_now:=nullif(trim(coalesce(input_image_url,'')),'') is not null;
  insert into public.prelude_catalog(name,brand,image_url,price_2ml,price_3ml,price_5ml,price_10ml,active)
  values(trim(input_name),trim(input_brand),nullif(trim(input_image_url),''),round(input_price_2ml,2),round(input_price_3ml,2),round(input_price_5ml,2),round(input_price_10ml,2),publish_now)
  returning id into new_id;
  return jsonb_build_object('success',true,'id',new_id,'active',publish_now);
exception when unique_violation then raise exception 'Ya existe un perfume con ese nombre.';
end;$$;
revoke all on function public.admin_create_prelude_catalog_product(text,text,text,numeric,numeric,numeric,numeric) from public;
grant execute on function public.admin_create_prelude_catalog_product(text,text,text,numeric,numeric,numeric,numeric) to authenticated;
