-- PRELUDE · ACTUALIZACIÓN DESCUENTOS Y MARCAPÁGINAS DE SETS
-- Ejecutar una vez si Prelude Sets ya está instalado en Supabase.

update public.prelude_sets
set discount_percent = case id
  when 'five' then 5
  when 'discovery' then 10
  when 'journey' then 10
  when 'match' then 5
  when 'curator' then 10
  else discount_percent
end,
bonus_bookmarks = case id
  when 'five' then 5
  when 'discovery' then 5
  when 'journey' then 5
  when 'match' then 5
  when 'curator' then 5
  else bonus_bookmarks
end,
updated_at = now()
where id in ('five','discovery','journey','match','curator');

notify pgrst, 'reload schema';
