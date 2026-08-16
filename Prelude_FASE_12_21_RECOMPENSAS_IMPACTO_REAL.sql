-- PRELUDE · FASE 12.21 · COSTE REAL DE RECOMPENSAS
-- Ejecutar una vez en Supabase SQL Editor.

create table if not exists public.prelude_reward_cost_ledger (
  id uuid primary key default gen_random_uuid(),
  customer_reward_id uuid not null unique,
  order_number text,
  total_cost numeric not null default 0 check (total_cost >= 0),
  cost_detail jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.prelude_reward_cost_ledger enable row level security;

create or replace function public.admin_record_prelude_reward_cost(
  input_customer_reward_id uuid,
  input_order_number text,
  input_total_cost numeric,
  input_cost_detail jsonb
) returns void
language plpgsql security definer set search_path=public
as $$
begin
  insert into public.prelude_reward_cost_ledger
    (customer_reward_id,order_number,total_cost,cost_detail)
  values
    (input_customer_reward_id,nullif(trim(input_order_number),''),greatest(coalesce(input_total_cost,0),0),coalesce(input_cost_detail,'[]'::jsonb))
  on conflict (customer_reward_id) do update
    set order_number=excluded.order_number,
        total_cost=excluded.total_cost,
        cost_detail=excluded.cost_detail,
        updated_at=now();
end $$;

create or replace function public.admin_list_prelude_reward_costs()
returns table(
  id uuid,
  customer_reward_id uuid,
  order_number text,
  total_cost numeric,
  cost_detail jsonb,
  reward_label text,
  customer_name text,
  created_at timestamptz
)
language sql security definer set search_path=public
as $$
  select
    l.id,l.customer_reward_id,l.order_number,l.total_cost,l.cost_detail,
    coalesce(to_jsonb(cr)->>'reward_label','Recompensa Prelude') as reward_label,
    coalesce(to_jsonb(c)->>'customer_name',to_jsonb(c)->>'name','Cliente') as customer_name,
    l.created_at
  from public.prelude_reward_cost_ledger l
  left join public.prelude_customer_rewards cr on cr.id=l.customer_reward_id
  left join public.prelude_customers c on c.id=cr.customer_id
  order by l.created_at desc;
$$;

revoke all on function public.admin_record_prelude_reward_cost(uuid,text,numeric,jsonb) from public;
revoke all on function public.admin_list_prelude_reward_costs() from public;
grant execute on function public.admin_record_prelude_reward_cost(uuid,text,numeric,jsonb) to authenticated;
grant execute on function public.admin_list_prelude_reward_costs() to authenticated;
