-- PRELUDE · AUTUMN DISCOVERY SET · DIAGNÓSTICO DEL INTENTO FALLIDO
-- SOLO LECTURA. No cambia pedidos, stock, precios ni estados.
-- No muestra datos personales del cliente.
-- Si hay filas, anota el ID, número y estado del pedido ANTES de volver a intentar comprar.

SELECT
  o.id AS pedido_id,
  o.order_number AS numero_pedido,
  o.created_at AS fecha_registro,
  o.status AS estado,
  o.order_total AS total_eur,
  (
    SELECT count(*)
    FROM jsonb_array_elements(COALESCE(o.items,'[]'::jsonb)) AS i(item)
    WHERE i.item->>'set_id'='autumn-2026'
  ) AS lineas_autumn,
  (
    SELECT count(DISTINCT i.item->>'set_instance')
    FROM jsonb_array_elements(COALESCE(o.items,'[]'::jsonb)) AS i(item)
    WHERE i.item->>'set_id'='autumn-2026'
  ) AS sets_autumn,
  (
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'perfume',i.item->>'name',
      'formato',i.item->>'size',
      'unidades',i.item->>'qty'
    )), '[]'::jsonb)
    FROM jsonb_array_elements(COALESCE(o.items,'[]'::jsonb)) AS i(item)
    WHERE i.item->>'set_id'='autumn-2026'
  ) AS componentes_autumn
FROM public.prelude_orders AS o
WHERE EXISTS (
  SELECT 1
  FROM jsonb_array_elements(COALESCE(o.items,'[]'::jsonb)) AS i(item)
  WHERE i.item->>'set_id'='autumn-2026'
)
ORDER BY o.created_at DESC
LIMIT 15;
