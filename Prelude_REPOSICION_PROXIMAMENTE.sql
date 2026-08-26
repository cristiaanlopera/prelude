-- PRELUDE · NUEVO ESTADO "REPOSICIÓN PRÓXIMAMENTE"
-- Ejecutar UNA VEZ en Supabase > SQL Editor > New query > Run.
-- No elimina ni reinicia ventas, pedidos, ranking ni estadísticas históricas.

-- 1) Permitir el nuevo estado en el catálogo.
alter table public.prelude_catalog
  drop constraint if exists prelude_catalog_availability_status_check;

alter table public.prelude_catalog
  add constraint prelude_catalog_availability_status_check
  check (availability_status in ('published','upcoming','restocking','soldout','hidden'));

-- 2) Permitir que Prelude Studio guarde el nuevo estado.
create or replace function public.admin_set_prelude_catalog_status(
  input_catalog_id uuid,
  input_status text
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare normalized text:=lower(trim(coalesce(input_status,'')));
begin
  if auth.uid() is null or not exists(
    select 1 from public.prelude_admins where user_id=auth.uid()
  ) then
    raise exception 'No tienes permisos de administrador.';
  end if;

  if normalized not in ('published','upcoming','restocking','soldout','hidden') then
    raise exception 'Estado de catálogo no válido.';
  end if;

  update public.prelude_catalog
  set availability_status=normalized,
      active=(normalized<>'hidden'),
      updated_at=now()
  where id=input_catalog_id
    and deleted_at is null;

  if not found then
    raise exception 'Perfume no encontrado.';
  end if;

  return jsonb_build_object(
    'success',true,
    'id',input_catalog_id,
    'availability_status',normalized
  );
end;
$$;

revoke all on function public.admin_set_prelude_catalog_status(uuid,text) from public;
grant execute on function public.admin_set_prelude_catalog_status(uuid,text) to authenticated;
