-- DESACTIVACIÓN DEL AUTUMN DISCOVERY SET (no modifica pedidos ni stock)
UPDATE public.prelude_autumn_offer_config
SET active=false,updated_at=now()
WHERE id='autumn-2026';
SELECT public.get_prelude_autumn_offer();
