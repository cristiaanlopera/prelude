-- PRELUDE · FASE 12.20 · MÁS VENDIDOS POR NÚMERO DE DECANTS
-- Ejecutar una vez en Supabase SQL Editor.

create or replace function public.get_prelude_public_bestsellers()
returns table (
  perfume_name text,
  decants_sold bigint
)
language sql
security definer
set search_path = public
as $$
  select
    trim(item->>'name') as perfume_name,
    sum(
      case
        when coalesce(item->>'qty','') ~ '^[0-9]+(?:\.[0-9]+)?$'
          then greatest(1, floor((item->>'qty')::numeric))::bigint
        else 1::bigint
      end
    ) as decants_sold
  from public.prelude_orders o
  cross join lateral jsonb_array_elements(coalesce(o.items,'[]'::jsonb)) item
  where o.status = 'delivered'
    and nullif(trim(item->>'name'),'') is not null
  group by trim(item->>'name')
  order by decants_sold desc, perfume_name asc;
$$;

revoke all on function public.get_prelude_public_bestsellers() from public;
grant execute on function public.get_prelude_public_bestsellers() to anon;
grant execute on function public.get_prelude_public_bestsellers() to authenticated;
