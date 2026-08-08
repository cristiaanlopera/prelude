-- Prelude Studio · Recompensas simplificadas
-- Ejecutar una sola vez en Supabase > SQL Editor.
create or replace function public.admin_create_prelude_reward_setting(input_threshold integer,input_reward_label text,input_active boolean default true)
returns jsonb language plpgsql security definer set search_path=public as $$
declare new_id text;
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then raise exception 'No tienes permisos de administrador.'; end if;
  if input_threshold is null or input_threshold < 1 or trim(coalesce(input_reward_label,''))='' then raise exception 'Datos de recompensa no válidos.'; end if;
  new_id := 'reward_' || replace(gen_random_uuid()::text,'-','');
  insert into public.prelude_reward_settings(id,threshold,reward_label,active,sort_order)
  values(new_id,input_threshold,trim(input_reward_label),coalesce(input_active,true),input_threshold);
  return jsonb_build_object('success',true,'id',new_id);
end; $$;

create or replace function public.admin_delete_prelude_reward_setting(input_id text)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then raise exception 'No tienes permisos de administrador.'; end if;
  delete from public.prelude_reward_settings where id=input_id;
  return jsonb_build_object('success',found);
end; $$;

revoke all on function public.admin_create_prelude_reward_setting(integer,text,boolean) from public;
grant execute on function public.admin_create_prelude_reward_setting(integer,text,boolean) to authenticated;
revoke all on function public.admin_delete_prelude_reward_setting(text) from public;
grant execute on function public.admin_delete_prelude_reward_setting(text) to authenticated;
