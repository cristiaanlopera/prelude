-- PRELUDE · FASE 12.22 · PROGRAMA DE RECOMPENSAS DE LANZAMIENTO
-- Ejecutar una vez en Supabase SQL Editor.

create table if not exists public.prelude_reward_rules (
  reward_id text primary key references public.prelude_reward_settings(id) on delete cascade,
  reward_type text not null default 'decant',
  discount_percent numeric,
  updated_at timestamptz not null default now()
);

alter table public.prelude_reward_rules enable row level security;

-- Las recompensas antiguas se conservan en la base de datos, pero quedan inactivas.
update public.prelude_reward_settings set active=false, updated_at=now();

insert into public.prelude_reward_settings(id,threshold,reward_label,active,sort_order)
values
 ('launch_reward_20',20,'2 ml a elegir',true,20),
 ('launch_reward_40',40,'5 ml a elegir',true,40),
 ('launch_reward_50',50,'10 % de descuento en el siguiente pedido',true,50),
 ('launch_reward_70',70,'2 × 5 ml a elegir',true,70),
 ('launch_reward_100',100,'30 % de descuento en el siguiente pedido',true,100)
on conflict(id) do update set
 threshold=excluded.threshold,
 reward_label=excluded.reward_label,
 active=true,
 sort_order=excluded.sort_order,
 updated_at=now();

insert into public.prelude_reward_rules(reward_id,reward_type,discount_percent)
values
 ('launch_reward_20','decant',null),
 ('launch_reward_40','decant',null),
 ('launch_reward_50','discount',10),
 ('launch_reward_70','decant',null),
 ('launch_reward_100','discount',30)
on conflict(reward_id) do update set
 reward_type=excluded.reward_type,
 discount_percent=excluded.discount_percent,
 updated_at=now();

create or replace function public.admin_apply_prelude_launch_rewards()
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then
    raise exception 'No tienes permisos de administrador.';
  end if;

  update public.prelude_reward_settings set active=false,updated_at=now();

  insert into public.prelude_reward_settings(id,threshold,reward_label,active,sort_order)
  values
   ('launch_reward_20',20,'2 ml a elegir',true,20),
   ('launch_reward_40',40,'5 ml a elegir',true,40),
   ('launch_reward_50',50,'10 % de descuento en el siguiente pedido',true,50),
   ('launch_reward_70',70,'2 × 5 ml a elegir',true,70),
   ('launch_reward_100',100,'30 % de descuento en el siguiente pedido',true,100)
  on conflict(id) do update set threshold=excluded.threshold,reward_label=excluded.reward_label,active=true,sort_order=excluded.sort_order,updated_at=now();

  insert into public.prelude_reward_rules(reward_id,reward_type,discount_percent)
  values
   ('launch_reward_20','decant',null),
   ('launch_reward_40','decant',null),
   ('launch_reward_50','discount',10),
   ('launch_reward_70','decant',null),
   ('launch_reward_100','discount',30)
  on conflict(reward_id) do update set reward_type=excluded.reward_type,discount_percent=excluded.discount_percent,updated_at=now();

  return jsonb_build_object('success',true);
end $$;

revoke all on function public.admin_apply_prelude_launch_rewards() from public;
grant execute on function public.admin_apply_prelude_launch_rewards() to authenticated;

create or replace function public.get_prelude_reward_rule(input_reward_id text)
returns jsonb
language sql
security definer
set search_path=public
as $$
 select coalesce(
   (select jsonb_build_object(
      'reward_id',r.reward_id,
      'reward_type',r.reward_type,
      'discount_percent',r.discount_percent
    ) from public.prelude_reward_rules r where r.reward_id=input_reward_id),
   '{}'::jsonb
 );
$$;

grant execute on function public.get_prelude_reward_rule(text) to anon, authenticated;
