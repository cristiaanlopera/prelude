-- PRELUDE · AUTUMN DISCOVERY SET · PROPUESTA DE MIGRACIÓN
-- Fecha: 2026-10-14. NO ejecutada ni contrastada contra el esquema de producción.
-- Leer el documento de integración antes de ejecutar.
-- Mantiene el Set DESACTIVADO por defecto.
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
ON CONFLICT(id) DO NOTHING;

-- Se insertan solo coincidencias ÚNICAS de nombre + marca.
-- Si alguna referencia no coincide, la venta permanecerá bloqueada.
WITH wanted(position,brand,name) AS (VALUES
    (1,'BDK Parfums','Gris Charnel'),
    (2,'Maison Margiela','Replica By The Fireplace'),
    (3,'Yves Saint Laurent','La Nuit de L''Homme'),
    (4,'Giorgio Armani','Stronger With You'),
    (5,'Mercedes-Benz','Mercedes-Benz Club Black')
), candidates AS (
    SELECT w.position,c.id,COUNT(*) OVER (PARTITION BY w.position) AS matches
    FROM wanted w
    JOIN public.prelude_catalog c
      ON lower(trim(c.brand))=lower(trim(w.brand))
     AND lower(trim(c.name))=lower(trim(w.name))
)
INSERT INTO public.prelude_autumn_offer_items(offer_id,catalog_id,position)
SELECT 'autumn-2026', id, position FROM candidates WHERE matches=1
ON CONFLICT DO NOTHING;

-- La disponibilidad descuenta la suma de ventas entregadas y pedidos no cancelados
-- para evitar comprometer ml que ya están solicitados. La lógica general de
-- stock del catálogo público sigue siendo la existente (no se altera aquí).
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

COMMIT;

-- VERIFICACIONES DE SOLO LECTURA (ejecutar después):
-- select * from public.prelude_autumn_offer_config;
-- select position,catalog_id from public.prelude_autumn_offer_items order by position;
-- select public.get_prelude_autumn_offer();
--
-- ACTIVAR SOLO TRAS VERIFICACIÓN DE STOCK, MARGEN, COSTES Y MARCO LEGAL:
-- update public.prelude_autumn_offer_config set active=true,updated_at=now()
-- where id='autumn-2026';
-- DESACTIVAR:
-- update public.prelude_autumn_offer_config set active=false,updated_at=now()
-- where id='autumn-2026';
