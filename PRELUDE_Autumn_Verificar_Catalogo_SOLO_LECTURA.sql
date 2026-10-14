-- PRELUDE AUTUMN · comprobación de referencias · SOLO LECTURA
-- Revisar resultados antes de ejecutar la migración propuesta.
SELECT
  c.id,
  c.brand,
  c.name,
  c.price_3ml,
  to_jsonb(c)->>'availability_status' AS estado,
  to_jsonb(c)->>'stock_initial_ml' AS ml_stock_inicial_registrado,
  to_jsonb(c)->>'low_stock_threshold_ml' AS umbral_stock_bajo,
  to_jsonb(c)->>'deleted_at' AS deleted_at
FROM public.prelude_catalog AS c
WHERE lower(c.name) LIKE '%gris charnel%'
   OR lower(c.name) LIKE '%fireplace%'
   OR lower(c.name) LIKE '%la nuit%'
   OR lower(c.name) LIKE '%stronger with you%'
   OR lower(c.name) LIKE '%club black%'
ORDER BY c.brand,c.name;

-- Si la función existe en tu esquema actual, permite consultar stock público:
-- SELECT public.get_prelude_catalog();
--
-- IMPORTANTE: `stock_initial_ml` no equivale necesariamente a stock libre actual.
-- Revisar los pedidos no cancelados y la existencia física antes de activar.
