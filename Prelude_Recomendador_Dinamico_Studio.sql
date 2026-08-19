-- PRELUDE · RECOMENDADOR DINÁMICO DESDE PRELUDE STUDIO
-- Ejecutar UNA VEZ en Supabase -> SQL Editor -> New query -> Run.

create extension if not exists unaccent;

alter table public.prelude_catalog
  add column if not exists recommender_profile jsonb null;

do $$
begin
  if not exists (select 1 from pg_constraint where conname='prelude_catalog_recommender_profile_check') then
    alter table public.prelude_catalog
      add constraint prelude_catalog_recommender_profile_check
      check (recommender_profile is null or jsonb_typeof(recommender_profile)='object');
  end if;
end $$;

-- Semilla de perfiles ya definidos.
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":5,"elegancia":4,"sensualidad":2,"caracter":3,"calidez":1},"moment":{"diario":4,"cita":2,"noche":2,"trabajo":4,"vacaciones":5},"presence":{"sutil":3,"equilibrada":5,"huella":2},"style":{"limpia":5,"citrica":3,"dulce":1,"amaderada":4,"marina":5,"oscura":1}}'::jsonb where lower(trim(name))=lower(trim('Le Sel d''Issey')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":2,"elegancia":3,"sensualidad":4,"caracter":4,"calidez":5},"moment":{"diario":2,"cita":4,"noche":5,"trabajo":2,"vacaciones":3},"presence":{"sutil":1,"equilibrada":2,"huella":5},"style":{"limpia":1,"citrica":2,"dulce":5,"amaderada":2,"marina":1,"oscura":3}}'::jsonb where lower(trim(name))=lower(trim('Amber Oud Gold Edition')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":1,"elegancia":5,"sensualidad":5,"caracter":4,"calidez":4},"moment":{"diario":2,"cita":5,"noche":5,"trabajo":4,"vacaciones":1},"presence":{"sutil":2,"equilibrada":4,"huella":4},"style":{"limpia":2,"citrica":1,"dulce":3,"amaderada":5,"marina":1,"oscura":4}}'::jsonb where lower(trim(name))=lower(trim('Dior Homme Intense')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":1,"elegancia":3,"sensualidad":5,"caracter":4,"calidez":5},"moment":{"diario":2,"cita":5,"noche":5,"trabajo":2,"vacaciones":1},"presence":{"sutil":1,"equilibrada":3,"huella":5},"style":{"limpia":1,"citrica":1,"dulce":5,"amaderada":4,"marina":1,"oscura":5}}'::jsonb where lower(trim(name))=lower(trim('Mercedes-Benz Club Black')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":5,"elegancia":3,"sensualidad":2,"caracter":2,"calidez":1},"moment":{"diario":5,"cita":2,"noche":1,"trabajo":4,"vacaciones":5},"presence":{"sutil":5,"equilibrada":3,"huella":1},"style":{"limpia":5,"citrica":5,"dulce":1,"amaderada":2,"marina":2,"oscura":1}}'::jsonb where lower(trim(name))=lower(trim('CK One')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":2,"elegancia":5,"sensualidad":5,"caracter":4,"calidez":4},"moment":{"diario":2,"cita":5,"noche":5,"trabajo":3,"vacaciones":1},"presence":{"sutil":3,"equilibrada":5,"huella":3},"style":{"limpia":2,"citrica":1,"dulce":3,"amaderada":5,"marina":1,"oscura":5}}'::jsonb where lower(trim(name))=lower(trim('La Nuit de L''Homme')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":5,"elegancia":4,"sensualidad":2,"caracter":4,"calidez":1},"moment":{"diario":4,"cita":3,"noche":2,"trabajo":4,"vacaciones":4},"presence":{"sutil":2,"equilibrada":4,"huella":4},"style":{"limpia":5,"citrica":5,"dulce":1,"amaderada":3,"marina":2,"oscura":1}}'::jsonb where lower(trim(name))=lower(trim('Club de Nuit Sillage')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":2,"elegancia":4,"sensualidad":4,"caracter":4,"calidez":5},"moment":{"diario":3,"cita":5,"noche":5,"trabajo":3,"vacaciones":1},"presence":{"sutil":2,"equilibrada":4,"huella":4},"style":{"limpia":2,"citrica":1,"dulce":5,"amaderada":4,"marina":1,"oscura":4}}'::jsonb where lower(trim(name))=lower(trim('Détour Noir')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":5,"elegancia":4,"sensualidad":2,"caracter":2,"calidez":2},"moment":{"diario":5,"cita":3,"noche":1,"trabajo":4,"vacaciones":5},"presence":{"sutil":4,"equilibrada":4,"huella":1},"style":{"limpia":4,"citrica":5,"dulce":2,"amaderada":3,"marina":2,"oscura":1}}'::jsonb where lower(trim(name))=lower(trim('Fico di Amalfi')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":3,"elegancia":3,"sensualidad":5,"caracter":5,"calidez":4},"moment":{"diario":2,"cita":5,"noche":5,"trabajo":1,"vacaciones":3},"presence":{"sutil":1,"equilibrada":2,"huella":5},"style":{"limpia":2,"citrica":3,"dulce":5,"amaderada":3,"marina":1,"oscura":4}}'::jsonb where lower(trim(name))=lower(trim('Eros')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":4,"elegancia":5,"sensualidad":3,"caracter":5,"calidez":2},"moment":{"diario":4,"cita":4,"noche":4,"trabajo":5,"vacaciones":3},"presence":{"sutil":2,"equilibrada":4,"huella":5},"style":{"limpia":4,"citrica":2,"dulce":1,"amaderada":5,"marina":1,"oscura":3}}'::jsonb where lower(trim(name))=lower(trim('Bois Impérial')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":4,"elegancia":5,"sensualidad":3,"caracter":4,"calidez":3},"moment":{"diario":4,"cita":4,"noche":3,"trabajo":4,"vacaciones":4},"presence":{"sutil":3,"equilibrada":5,"huella":2},"style":{"limpia":4,"citrica":4,"dulce":2,"amaderada":5,"marina":1,"oscura":2}}'::jsonb where lower(trim(name))=lower(trim('Bal d''Afrique')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":5,"elegancia":3,"sensualidad":2,"caracter":2,"calidez":1},"moment":{"diario":5,"cita":2,"noche":1,"trabajo":3,"vacaciones":5},"presence":{"sutil":4,"equilibrada":4,"huella":1},"style":{"limpia":5,"citrica":2,"dulce":1,"amaderada":2,"marina":5,"oscura":1}}'::jsonb where lower(trim(name))=lower(trim('Le Rem')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":3,"elegancia":3,"sensualidad":5,"caracter":4,"calidez":4},"moment":{"diario":3,"cita":5,"noche":4,"trabajo":1,"vacaciones":5},"presence":{"sutil":2,"equilibrada":4,"huella":4},"style":{"limpia":2,"citrica":2,"dulce":5,"amaderada":2,"marina":2,"oscura":3}}'::jsonb where lower(trim(name))=lower(trim('Le Beau')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":1,"elegancia":4,"sensualidad":5,"caracter":4,"calidez":5},"moment":{"diario":2,"cita":5,"noche":5,"trabajo":2,"vacaciones":1},"presence":{"sutil":2,"equilibrada":4,"huella":4},"style":{"limpia":1,"citrica":1,"dulce":5,"amaderada":3,"marina":1,"oscura":4}}'::jsonb where lower(trim(name))=lower(trim('Stronger With You')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":5,"elegancia":5,"sensualidad":2,"caracter":4,"calidez":1},"moment":{"diario":5,"cita":3,"noche":2,"trabajo":5,"vacaciones":5},"presence":{"sutil":3,"equilibrada":5,"huella":3},"style":{"limpia":5,"citrica":5,"dulce":1,"amaderada":2,"marina":1,"oscura":1}}'::jsonb where lower(trim(name))=lower(trim('Torino 21')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":4,"elegancia":2,"sensualidad":3,"caracter":2,"calidez":2},"moment":{"diario":5,"cita":3,"noche":2,"trabajo":3,"vacaciones":5},"presence":{"sutil":4,"equilibrada":4,"huella":1},"style":{"limpia":4,"citrica":3,"dulce":3,"amaderada":2,"marina":3,"oscura":1}}'::jsonb where lower(trim(name))=lower(trim('First Instinct')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":1,"elegancia":2,"sensualidad":4,"caracter":5,"calidez":5},"moment":{"diario":1,"cita":4,"noche":5,"trabajo":1,"vacaciones":1},"presence":{"sutil":1,"equilibrada":2,"huella":5},"style":{"limpia":1,"citrica":1,"dulce":5,"amaderada":2,"marina":1,"oscura":5}}'::jsonb where lower(trim(name))=lower(trim('Egeo Bomb Black')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":2,"elegancia":5,"sensualidad":5,"caracter":4,"calidez":4},"moment":{"diario":3,"cita":5,"noche":5,"trabajo":4,"vacaciones":1},"presence":{"sutil":2,"equilibrada":5,"huella":3},"style":{"limpia":2,"citrica":2,"dulce":3,"amaderada":4,"marina":1,"oscura":5}}'::jsonb where lower(trim(name))=lower(trim('Armani Code')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":4,"elegancia":4,"sensualidad":2,"caracter":2,"calidez":2},"moment":{"diario":5,"cita":3,"noche":2,"trabajo":5,"vacaciones":4},"presence":{"sutil":5,"equilibrada":3,"huella":1},"style":{"limpia":5,"citrica":3,"dulce":1,"amaderada":4,"marina":2,"oscura":1}}'::jsonb where lower(trim(name))=lower(trim('Starwalker')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":5,"elegancia":2,"sensualidad":2,"caracter":2,"calidez":1},"moment":{"diario":5,"cita":2,"noche":1,"trabajo":3,"vacaciones":5},"presence":{"sutil":5,"equilibrada":3,"huella":1},"style":{"limpia":5,"citrica":2,"dulce":2,"amaderada":2,"marina":5,"oscura":1}}'::jsonb where lower(trim(name))=lower(trim('Nautica Voyage')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":5,"elegancia":3,"sensualidad":2,"caracter":3,"calidez":1},"moment":{"diario":5,"cita":2,"noche":2,"trabajo":4,"vacaciones":5},"presence":{"sutil":4,"equilibrada":4,"huella":2},"style":{"limpia":5,"citrica":2,"dulce":1,"amaderada":3,"marina":5,"oscura":1}}'::jsonb where lower(trim(name))=lower(trim('Cool Water')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":4,"elegancia":4,"sensualidad":4,"caracter":5,"calidez":3},"moment":{"diario":5,"cita":4,"noche":4,"trabajo":4,"vacaciones":4},"presence":{"sutil":1,"equilibrada":3,"huella":5},"style":{"limpia":4,"citrica":4,"dulce":1,"amaderada":3,"marina":2,"oscura":3}}'::jsonb where lower(trim(name))=lower(trim('Sauvage')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":5,"elegancia":4,"sensualidad":3,"caracter":3,"calidez":1},"moment":{"diario":5,"cita":3,"noche":2,"trabajo":4,"vacaciones":5},"presence":{"sutil":3,"equilibrada":5,"huella":2},"style":{"limpia":5,"citrica":5,"dulce":1,"amaderada":2,"marina":5,"oscura":1}}'::jsonb where lower(unaccent(name)) like lower(unaccent('%acqua di gio%')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":4,"elegancia":4,"sensualidad":4,"caracter":5,"calidez":3},"moment":{"diario":4,"cita":4,"noche":4,"trabajo":4,"vacaciones":4},"presence":{"sutil":1,"equilibrada":3,"huella":5},"style":{"limpia":4,"citrica":4,"dulce":1,"amaderada":4,"marina":4,"oscura":3}}'::jsonb where lower(unaccent(name)) like lower(unaccent('%dylan blue%')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":1,"elegancia":4,"sensualidad":5,"caracter":4,"calidez":5},"moment":{"diario":2,"cita":5,"noche":5,"trabajo":2,"vacaciones":1},"presence":{"sutil":1,"equilibrada":3,"huella":5},"style":{"limpia":1,"citrica":1,"dulce":5,"amaderada":3,"marina":1,"oscura":4}}'::jsonb where lower(unaccent(name)) like lower(unaccent('%born in roma intense%')) and recommender_profile is null;
update public.prelude_catalog set recommender_profile='{"mood":{"frescura":4,"elegancia":5,"sensualidad":3,"caracter":5,"calidez":3},"moment":{"diario":5,"cita":3,"noche":3,"trabajo":5,"vacaciones":4},"presence":{"sutil":2,"equilibrada":5,"huella":3},"style":{"limpia":3,"citrica":5,"dulce":1,"amaderada":5,"marina":1,"oscura":3}}'::jsonb where lower(unaccent(name)) like lower(unaccent('%terre d''herm%')) and recommender_profile is null;

create or replace function public.get_prelude_catalog()
returns jsonb
language sql
security definer
set search_path=public
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id',c.id,'name',c.name,'brand',c.brand,
        'active',case when c.deleted_at is null then c.active else false end,
        'availability_status',case when c.deleted_at is null then c.availability_status else 'hidden' end,
        'display_order',c.display_order,
        'price_2ml',c.price_2ml,'price_3ml',c.price_3ml,'price_5ml',c.price_5ml,'price_10ml',c.price_10ml,
        'image_url',c.image_url,'description',c.description,'accords',to_jsonb(c.accords),'notes',to_jsonb(c.notes),
        'journey_theme',c.journey_theme,'journey_title',c.journey_title,'journey_copy',c.journey_copy,
        'recommender_profile',c.recommender_profile,
        'low_stock_threshold_ml',c.low_stock_threshold_ml,
        'stock_available_ml',case when c.stock_initial_ml is null then null else greatest(0,c.stock_initial_ml-coalesce(s.sold_ml,0)) end,
        'created_at',c.created_at,'updated_at',c.updated_at
      )
      order by case when c.deleted_at is not null then 4 when c.availability_status='upcoming' then 0 when c.availability_status='published' then 1 when c.availability_status='soldout' then 2 else 3 end,
      c.display_order,c.created_at,c.name
    ),'[]'::jsonb
  )
  from public.prelude_catalog c
  left join lateral (
    select sum(coalesce(nullif(regexp_replace(item->>'size','[^0-9.]','','g'),'')::numeric,0)*coalesce(nullif(item->>'qty','')::numeric,1)) as sold_ml
    from public.prelude_orders o cross join lateral jsonb_array_elements(o.items) item
    where o.status='delivered' and trim(item->>'name')=c.name
  ) s on true;
$$;

revoke all on function public.get_prelude_catalog() from public;
grant execute on function public.get_prelude_catalog() to anon,authenticated;

create or replace function public.admin_list_prelude_catalog()
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
    'id',c.id,'name',c.name,'brand',c.brand,'active',c.active,
    'availability_status',c.availability_status,'display_order',c.display_order,
    'price_2ml',c.price_2ml,'price_3ml',c.price_3ml,'price_5ml',c.price_5ml,'price_10ml',c.price_10ml,
    'image_url',c.image_url,'stock_initial_ml',c.stock_initial_ml,'low_stock_threshold_ml',c.low_stock_threshold_ml,
    'recommender_profile',c.recommender_profile,
    'sold_ml',coalesce(s.sold_ml,0),
    'stock_available_ml',case when c.stock_initial_ml is null then null else greatest(0,c.stock_initial_ml-coalesce(s.sold_ml,0)) end
  ) order by case when c.availability_status='upcoming' then 0 when c.availability_status='published' then 1 when c.availability_status='soldout' then 2 else 3 end,c.display_order,c.name),'[]'::jsonb)
  into result
  from public.prelude_catalog c
  left join lateral (
    select sum(coalesce(nullif(regexp_replace(item->>'size','[^0-9.]','','g'),'')::numeric,0)*coalesce(nullif(item->>'qty','')::numeric,1)) as sold_ml
    from public.prelude_orders o cross join lateral jsonb_array_elements(o.items) item
    where o.status='delivered' and trim(item->>'name')=c.name
  ) s on true
  where c.deleted_at is null;

  return result;
end;
$$;

revoke all on function public.admin_list_prelude_catalog() from public;
grant execute on function public.admin_list_prelude_catalog() to authenticated;

create or replace function public.admin_set_prelude_recommender_profile(input_catalog_id uuid,input_profile jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare group_name text; key_name text; score numeric;
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then
    raise exception 'No tienes permisos de administrador.';
  end if;

  if input_profile is not null then
    if jsonb_typeof(input_profile)<>'object' then raise exception 'El perfil debe ser un objeto JSON.'; end if;

    foreach group_name in array array['mood','moment','presence','style'] loop
      if not (input_profile ? group_name) or jsonb_typeof(input_profile->group_name)<>'object' then
        raise exception 'Perfil incompleto: falta %.',group_name;
      end if;
    end loop;

    for group_name,key_name in
      select g,k from (values
        ('mood','frescura'),('mood','elegancia'),('mood','sensualidad'),('mood','caracter'),('mood','calidez'),
        ('moment','diario'),('moment','cita'),('moment','noche'),('moment','trabajo'),('moment','vacaciones'),
        ('presence','sutil'),('presence','equilibrada'),('presence','huella'),
        ('style','limpia'),('style','citrica'),('style','dulce'),('style','amaderada'),('style','marina'),('style','oscura')
      ) as required(g,k)
    loop
      if not ((input_profile->group_name) ? key_name) then raise exception 'Perfil incompleto: falta %.%.',group_name,key_name; end if;
      score:=(input_profile->group_name->>key_name)::numeric;
      if score<1 or score>5 then raise exception 'Las puntuaciones deben estar entre 1 y 5.'; end if;
    end loop;
  end if;

  update public.prelude_catalog set recommender_profile=input_profile,updated_at=now()
  where id=input_catalog_id and deleted_at is null;
  if not found then raise exception 'Perfume no encontrado.'; end if;

  return jsonb_build_object('success',true,'id',input_catalog_id,'configured',input_profile is not null);
end;
$$;

revoke all on function public.admin_set_prelude_recommender_profile(uuid,jsonb) from public;
grant execute on function public.admin_set_prelude_recommender_profile(uuid,jsonb) to authenticated;
