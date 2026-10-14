-- PRELUDE · AUTUMN DISCOVERY SET · DIAGNÓSTICO TRAS INSTALAR MIGRACIÓN.
-- SOLO LECTURA. No modifica ventas ni existencias.
SELECT
  i.position, c.id, c.brand, c.name, c.availability_status,
  c.stock_initial_ml,
  COALESCE(s.sold_ml,0) AS entregado_ml_historico,
  public.prelude_autumn_ml_reserved(c.id) AS reservado_autumn_ml,
  CASE WHEN c.stock_initial_ml IS NULL THEN NULL ELSE
    GREATEST(0,c.stock_initial_ml-COALESCE(s.sold_ml,0)
      -public.prelude_autumn_ml_reserved(c.id))
  END AS disponible_calculado_ml
FROM public.prelude_autumn_offer_items i
JOIN public.prelude_catalog c ON c.id=i.catalog_id
LEFT JOIN LATERAL (
  SELECT SUM(
    COALESCE(NULLIF(regexp_replace(item->>'size','[^0-9.]','','g'),'')::numeric,0)
    *COALESCE(NULLIF(item->>'qty','')::numeric,1)
  ) AS sold_ml
  FROM public.prelude_orders o,
       LATERAL jsonb_array_elements(o.items) item
  WHERE o.status='delivered' AND trim(item->>'name')=c.name
) s ON true
WHERE i.offer_id='autumn-2026'
ORDER BY i.position;

SELECT public.get_prelude_autumn_offer() AS configuracion_y_disponibilidad;
