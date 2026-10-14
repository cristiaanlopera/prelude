-- PRELUDE · AUTUMN DISCOVERY SET · MIGRACIÓN ADAPTADA A FUNCIONES RECUPERADAS DE SUPABASE
-- Fecha 2026-10-14 | Estado: PREPARADA; NO ejecutada ni verificada en Supabase real.
-- BASE: definiciones pegadas por el usuario para get_prelude_catalog,
-- admin_list_prelude_catalog, admin_set_prelude_catalog_stock,
-- create_prelude_order y admin_update_prelude_order_status.
-- Uso: ejecutar completo en Supabase SQL Editor una sola vez (idempotente en gran parte).
-- Configuración permanece INACTIVA. No crea límite máximo comercial ni escribe ml físicos.
-- NOTA: antes de ejecutar, exportar/copiar las definiciones originales de las 3 funciones sustituidas.
-- No modificar create_prelude_order ni admin_update_prelude_order_status.
-- Si un paso falla antes de COMMIT, toda la migración se revierte automáticamente.
BEGIN;

CREATE TABLE IF NOT EXISTS public.prelude_autumn_offer_config (
    id text PRIMARY KEY CHECK (id = 'autumn-2026'),
    active boolean NOT NULL DEFAULT false,
    fixed_price numeric(10,2) NOT NULL DEFAULT 20.00 CHECK (fixed_price = 20.00),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.prelude_autumn_offer_items (
    offer_id text NOT NULL REFERENCES public.prelude_autumn_offer_config(id) ON DELETE CASCADE,
    catalog_id uuid NOT NULL REFERENCES public.prelude_catalog(id),
    position integer NOT NULL CHECK (position BETWEEN 1 AND 5),
    PRIMARY KEY (offer_id, catalog_id),
    UNIQUE (offer_id, position)
);
ALTER TABLE public.prelude_autumn_offer_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prelude_autumn_offer_items ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.prelude_autumn_offer_config FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.prelude_autumn_offer_items FROM PUBLIC, anon, authenticated;

INSERT INTO public.prelude_autumn_offer_config(id,active,fixed_price)
VALUES ('autumn-2026',false,20.00)
ON CONFLICT(id) DO UPDATE SET active=false, fixed_price=20.00,updated_at=now();

-- IDs comprobados contra el resultado facilitado por el usuario el 14/10/2026.
-- Excluye expresamente el duplicado oculto By The Fireplace sin precio.
INSERT INTO public.prelude_autumn_offer_items (offer_id,catalog_id,position)
VALUES
  ('autumn-2026','22d3ba81-eab3-4f6b-ab8a-a6de229cd8db',1),
  ('autumn-2026','b7cb2bbe-bb43-4eb5-bfd5-2cd54227ec24',2),
  ('autumn-2026','10a363f2-6768-4b57-b22b-db4a9b9f935e',3),
  ('autumn-2026','6a9977e6-326f-42f5-b34b-64d04424da60',4),
  ('autumn-2026','06d9d432-aaf9-4f54-a5a2-eeab4fe89e69',5)
ON CONFLICT (offer_id,catalog_id) DO UPDATE
SET position=EXCLUDED.position;

DO $assert_catalog$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM public.prelude_autumn_offer_items WHERE offer_id='autumn-2026';
  IF n <> 5 THEN RAISE EXCEPTION 'Autumn: se esperaban 5 componentes y se encontraron %.',n; END IF;
  IF EXISTS (
    SELECT 1 FROM public.prelude_autumn_offer_items i
    JOIN public.prelude_catalog c ON c.id=i.catalog_id
    WHERE i.offer_id='autumn-2026' AND
      (c.name IS DISTINCT FROM CASE i.position
        WHEN 1 THEN 'Gris Charnel'
        WHEN 2 THEN 'Replica By The Fireplace'
        WHEN 3 THEN 'La Nuit de L''Homme'
        WHEN 4 THEN 'Stronger With You'
        WHEN 5 THEN 'Mercedes-Benz Club Black'
      END
       OR c.brand IS DISTINCT FROM CASE i.position
        WHEN 1 THEN 'BDK Parfums'
        WHEN 2 THEN 'Maison Margiela'
        WHEN 3 THEN 'Yves Saint Laurent'
        WHEN 4 THEN 'Giorgio Armani'
        WHEN 5 THEN 'Mercedes-Benz'
      END)
  ) THEN RAISE EXCEPTION 'Autumn: los cinco IDs ya no corresponden a los perfumes verificados.'; END IF;
END;
$assert_catalog$;

CREATE OR REPLACE FUNCTION public.get_prelude_autumn_offer()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp
AS $$
DECLARE
  cfg public.prelude_autumn_offer_config%ROWTYPE;
  entries jsonb;
  valid_count integer;
  ready boolean;
BEGIN
  SELECT * INTO cfg FROM public.prelude_autumn_offer_config WHERE id='autumn-2026';
  IF NOT FOUND THEN RETURN jsonb_build_object('active',false,'ready',false,'components','[]'::jsonb); END IF;
  SELECT count(*) INTO valid_count
    FROM public.prelude_autumn_offer_items WHERE offer_id=cfg.id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'catalog_id',c.id,
      'name',c.name,
      'brand',c.brand,
      'position',i.position,
      'price_3ml',c.price_3ml,
      'availability_status',c.availability_status,
      'remaining_ml',CASE WHEN c.stock_initial_ml IS NULL THEN NULL
        ELSE GREATEST(0,c.stock_initial_ml-COALESCE(s.committed_ml,0)) END
    ) ORDER BY i.position),'[]'::jsonb)
  INTO entries
  FROM public.prelude_autumn_offer_items i
  JOIN public.prelude_catalog c ON c.id=i.catalog_id
  LEFT JOIN LATERAL (
    SELECT COALESCE(SUM(
      COALESCE(NULLIF(replace(regexp_replace(elem->>'size','[^0-9.,]','','g'),',','.'),'')::numeric,0)
      * COALESCE(NULLIF(elem->>'qty','')::numeric,1)),0) AS committed_ml
    FROM public.prelude_orders o
    CROSS JOIN LATERAL jsonb_array_elements(o.items) AS elem
    WHERE o.status IN ('pending','preparing','ready','delivered')
      AND trim(elem->>'name')=c.name
  ) s ON true
  WHERE i.offer_id=cfg.id;

  SELECT (valid_count=5) AND NOT EXISTS (
    SELECT 1
    FROM public.prelude_autumn_offer_items i
    JOIN public.prelude_catalog c ON c.id=i.catalog_id
    LEFT JOIN LATERAL (
      SELECT COALESCE(SUM(
        COALESCE(NULLIF(replace(regexp_replace(elem->>'size','[^0-9.,]','','g'),',','.'),'')::numeric,0)
        * COALESCE(NULLIF(elem->>'qty','')::numeric,1)),0) AS committed_ml
      FROM public.prelude_orders o
      CROSS JOIN LATERAL jsonb_array_elements(o.items) AS elem
      WHERE o.status IN ('pending','preparing','ready','delivered')
        AND trim(elem->>'name')=c.name
    ) s ON true
    WHERE i.offer_id=cfg.id
      AND (c.availability_status<>'published'
        OR c.active IS DISTINCT FROM true OR c.deleted_at IS NOT NULL
        OR c.price_3ml IS NULL OR c.price_3ml<=0
        OR c.stock_initial_ml IS NULL
        OR c.stock_initial_ml-COALESCE(s.committed_ml,0)<3)
  ) INTO ready;

  RETURN jsonb_build_object(
    'id',cfg.id, 'active',cfg.active,'ready',ready,
    'fixed_price',cfg.fixed_price,'components',entries
  );
END;
$$;
REVOKE ALL ON FUNCTION public.get_prelude_autumn_offer() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_prelude_autumn_offer() TO anon,authenticated;

-- Validación del servidor en la transacción que inserta el pedido.
-- El cliente no puede decidir libremente la composición, el total del set o su bonus.
CREATE OR REPLACE FUNCTION public.prelude_validate_autumn_order()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp
AS $$
DECLARE
  offer jsonb;
  autumn_count integer;
  group_id text;
  n integer;
  n_matching integer;
  total numeric;
  bonus_bad integer;
  component jsonb;
  requested_ml numeric;
  available_ml numeric;
  item jsonb;
BEGIN
  IF NEW.items IS NULL OR jsonb_typeof(NEW.items)<>'array' THEN RETURN NEW; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(NEW.items) item WHERE item->>'set_id'='autumn-2026'
  ) THEN RETURN NEW; END IF;

  PERFORM pg_advisory_xact_lock(17262940); -- serializa pedidos Autumn entre sí
  offer:=public.get_prelude_autumn_offer();
  IF NOT COALESCE((offer->>'active')::boolean,false)
     OR NOT COALESCE((offer->>'ready')::boolean,false)
  THEN RAISE EXCEPTION 'Autumn Discovery Set no disponible. Verifica su activación y stock.'; END IF;

  FOR group_id IN
    SELECT DISTINCT item->>'set_instance' FROM jsonb_array_elements(NEW.items) item
    WHERE item->>'set_id'='autumn-2026'
  LOOP
    IF COALESCE(trim(group_id),'')='' THEN RAISE EXCEPTION 'Instancia de set no válida.'; END IF;
    SELECT count(*),COALESCE(sum((item->>'price')::numeric),0),COUNT(*) FILTER (
      WHERE item->>'size'<>'3 ml' OR (item->>'qty')::numeric<>1
      OR item->>'set_name'<>'Autumn Discovery Set'
      OR (item->>'price')::numeric <= 0
      OR COALESCE((item->>'set_bonus_bookmarks')::integer,0)<>0
    )
    INTO n,total,bonus_bad
    FROM jsonb_array_elements(NEW.items) item
    WHERE item->>'set_id'='autumn-2026' AND item->>'set_instance'=group_id;

    IF n<>5 OR round(total,2)<>(offer->>'fixed_price')::numeric OR bonus_bad<>0 THEN
      RAISE EXCEPTION 'Composición o precio incorrectos del Autumn Discovery Set.'; END IF;
    -- Cada componente debe coincidir con el ID y el nombre que figuran en catálogo.
    SELECT count(DISTINCT cfg.catalog_id) INTO n_matching
    FROM jsonb_array_elements(NEW.items) item
    JOIN public.prelude_autumn_offer_items cfg
      ON cfg.offer_id='autumn-2026'
     AND cfg.catalog_id::text=item->>'catalog_id'
    JOIN public.prelude_catalog c ON c.id=cfg.catalog_id
    WHERE item->>'set_id'='autumn-2026'
      AND item->>'set_instance'=group_id
      AND item->>'name'=c.name;
    IF n_matching<>5 THEN RAISE EXCEPTION 'Los artículos del set no coinciden con el catálogo.'; END IF;
  END LOOP;

  SELECT count(DISTINCT item->>'set_instance')
  INTO autumn_count
  FROM jsonb_array_elements(NEW.items) item
  WHERE item->>'set_id'='autumn-2026';
  IF NEW.order_total IS NULL
     OR NEW.order_total < autumn_count * 20.00
  THEN RAISE EXCEPTION 'El total del pedido no cubre el precio del Autumn Discovery Set.'; END IF;

  FOR component IN SELECT value FROM jsonb_array_elements(offer->'components') LOOP
    SELECT COALESCE(SUM(
      COALESCE(NULLIF(replace(regexp_replace(item->>'size','[^0-9.,]','','g'),',','.'),'')::numeric,0)
      * COALESCE(NULLIF(item->>'qty','')::numeric,1)),0)
    INTO requested_ml
    FROM jsonb_array_elements(NEW.items) item
    WHERE item->>'name'=component->>'name';
    available_ml:=(component->>'remaining_ml')::numeric;
    IF available_ml IS NULL OR requested_ml>available_ml THEN
      RAISE EXCEPTION 'Stock insuficiente para %',component->>'name';
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.prelude_validate_autumn_order() FROM PUBLIC;
DROP TRIGGER IF EXISTS prelude_check_autumn_order ON public.prelude_orders;
CREATE TRIGGER prelude_check_autumn_order
BEFORE INSERT ON public.prelude_orders
FOR EACH ROW EXECUTE FUNCTION public.prelude_validate_autumn_order();

-- Evita registrar dos pedidos del mismo set por un reintento con el mismo identificador.
CREATE TABLE IF NOT EXISTS public.prelude_autumn_order_instances (
  instance_id text PRIMARY KEY,
  order_id uuid NOT NULL REFERENCES public.prelude_orders(id)
);
ALTER TABLE public.prelude_autumn_order_instances ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.prelude_autumn_order_instances FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.prelude_register_autumn_order_instance()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp
AS $$
DECLARE instance text;
BEGIN
  IF NEW.items IS NULL OR jsonb_typeof(NEW.items)<>'array' THEN RETURN NEW; END IF;
  FOR instance IN
    SELECT DISTINCT item->>'set_instance'
    FROM jsonb_array_elements(NEW.items) item
    WHERE item->>'set_id'='autumn-2026'
  LOOP
    INSERT INTO public.prelude_autumn_order_instances(instance_id,order_id)
    VALUES(instance,NEW.id)
    ON CONFLICT DO NOTHING;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Este Autumn Discovery Set ya fue registrado en otro pedido.';
    END IF;
  END LOOP;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.prelude_register_autumn_order_instance() FROM PUBLIC;
DROP TRIGGER IF EXISTS prelude_register_autumn_order ON public.prelude_orders;
CREATE TRIGGER prelude_register_autumn_order
AFTER INSERT ON public.prelude_orders
FOR EACH ROW EXECUTE FUNCTION public.prelude_register_autumn_order_instance();


CREATE OR REPLACE FUNCTION public.prelude_autumn_ml_reserved(input_catalog_id uuid)
RETURNS numeric
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path=public,pg_temp
AS $$
  SELECT COALESCE(SUM(3), 0)
  FROM public.prelude_orders AS o
  CROSS JOIN LATERAL jsonb_array_elements(o.items) AS i(item)
  WHERE o.status IN ('pending', 'preparing', 'ready')
    AND i.item->>'set_id' = 'autumn-2026'
    AND i.item->>'catalog_id' = input_catalog_id::text
    AND i.item->>'size' = '3 ml'
    AND i.item->>'qty' = '1';
$$;
REVOKE ALL ON FUNCTION public.prelude_autumn_ml_reserved(uuid) FROM PUBLIC,anon,authenticated;


-- VERSIÓN ORIGINAL DEL USUARIO, MODIFICADA SOLO EN stock_available_ml.
CREATE OR REPLACE FUNCTION public.get_prelude_catalog()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
        'stock_available_ml',case when c.stock_initial_ml is null then null else greatest(0,c.stock_initial_ml-coalesce(s.sold_ml,0)-public.prelude_autumn_ml_reserved(c.id)) end,
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_list_prelude_catalog()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    'stock_available_ml',case when c.stock_initial_ml is null then null else greatest(0,c.stock_initial_ml-coalesce(s.sold_ml,0)-public.prelude_autumn_ml_reserved(c.id)) end
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
$function$;

-- Setter: ajusta initial por ventas entregadas y por reservas Autumn abiertas.
CREATE OR REPLACE FUNCTION public.admin_set_prelude_catalog_stock(input_catalog_id uuid, input_available_ml numeric, input_low_stock_threshold_ml numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare sold numeric:=0;
begin
  if auth.uid() is null or not exists(select 1 from public.prelude_admins where user_id=auth.uid()) then raise exception 'No tienes permisos de administrador.'; end if;
  if input_available_ml<0 or input_low_stock_threshold_ml<0 then raise exception 'Valores de stock no válidos.'; end if;
  PERFORM pg_advisory_xact_lock(17262940);
  select coalesce(sum(coalesce(nullif(regexp_replace(item->>'size','[^0-9.]','','g'),'')::numeric,0)*coalesce(nullif(item->>'qty','')::numeric,1)),0) into sold
  from public.prelude_orders o cross join lateral jsonb_array_elements(o.items) item
  where o.status='delivered' and trim(item->>'name')=(select name from public.prelude_catalog where id=input_catalog_id);
  update public.prelude_catalog set stock_initial_ml=round(input_available_ml+sold+public.prelude_autumn_ml_reserved(input_catalog_id),2),low_stock_threshold_ml=round(input_low_stock_threshold_ml,2),updated_at=now() where id=input_catalog_id;
  if not found then raise exception 'Perfume no encontrado.'; end if;
  return jsonb_build_object('success',true,'id',input_catalog_id,'available_ml',input_available_ml,'sold_ml',sold,'reserved_autumn_ml',public.prelude_autumn_ml_reserved(input_catalog_id));
end;$function$;

-- Conserva las propiedades, campos y comprobaciones originales del catálogo,
-- y resta solo reservas Autumn de pedidos aún no entregados.
-- En entregados se cuenta el consumo histórico; en cancelados, ninguno.

-- El motor de Studio conservará sus permisos administrativos.
-- No se modifican recompensas, biblioteca, impresión, pedidos históricos ni sets previos.

NOTIFY pgrst, 'reload schema';
COMMIT;

-- COMPROBAR EN CONSULTA SEPARADA:
-- SELECT public.get_prelude_autumn_offer();
-- SELECT id,active,fixed_price FROM public.prelude_autumn_offer_config;
-- SELECT * FROM public.prelude_autumn_offer_items ORDER BY position;
--
-- NO ACTIVA LA VENTA: tres perfumes todavía no tienen stock físico verificado.
