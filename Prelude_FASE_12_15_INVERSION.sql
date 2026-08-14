-- PRELUDE · FASE 12.15 · INVERSIÓN
-- Ejecutar en Supabase SQL Editor para persistencia multi-dispositivo.
create table if not exists public.prelude_investments (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  units numeric not null default 1 check (units >= 0),
  unit_price numeric not null default 0 check (unit_price >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.prelude_investments enable row level security;

create or replace function public.admin_list_prelude_investments()
returns setof public.prelude_investments
language sql security definer set search_path=public
as $$ select * from public.prelude_investments order by created_at desc; $$;

create or replace function public.admin_upsert_prelude_investment(
  input_id uuid, input_name text, input_units numeric, input_unit_price numeric
) returns public.prelude_investments
language plpgsql security definer set search_path=public
as $$
declare r public.prelude_investments;
begin
  if input_id is null then
    insert into public.prelude_investments(name,units,unit_price)
    values(trim(input_name),greatest(input_units,0),greatest(input_unit_price,0))
    returning * into r;
  else
    update public.prelude_investments
    set name=trim(input_name),units=greatest(input_units,0),unit_price=greatest(input_unit_price,0),updated_at=now()
    where id=input_id returning * into r;
  end if;
  return r;
end $$;

create or replace function public.admin_delete_prelude_investment(input_id uuid)
returns boolean language plpgsql security definer set search_path=public
as $$
begin
  delete from public.prelude_investments where id=input_id;
  return found;
end $$;

grant execute on function public.admin_list_prelude_investments() to authenticated;
grant execute on function public.admin_upsert_prelude_investment(uuid,text,numeric,numeric) to authenticated;
grant execute on function public.admin_delete_prelude_investment(uuid) to authenticated;
