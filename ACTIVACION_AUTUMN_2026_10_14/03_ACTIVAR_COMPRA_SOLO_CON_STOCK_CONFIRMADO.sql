-- PRELUDE · AUTUMN DISCOVERY SET · ACTIVACIÓN DEL BOTÓN DE COMPRA
-- EJECUTAR SOLO después de instalar 01_...sql,
-- registrar en Prelude Studio el stock físico DISPONIBLE de los 5 perfumes,
-- comprobar las cifras y desplegar en Netlify el ZIP comercial.
-- No establece máximos de unidades: controla ml reales.
BEGIN;
DO $activate$
DECLARE oferta jsonb;
BEGIN
  oferta := public.get_prelude_autumn_offer();
  IF oferta->>'id' IS DISTINCT FROM 'autumn-2026'
     OR COALESCE((oferta->>'ready')::boolean,false) IS DISTINCT FROM true
  THEN
    RAISE EXCEPTION 'AUTUMN NO ACTIVADO: falta stock real registrado o una referencia no está publicada. Resultado: %', oferta;
  END IF;
  UPDATE public.prelude_autumn_offer_config
  SET active=true,updated_at=now()
  WHERE id='autumn-2026';
  IF NOT FOUND THEN RAISE EXCEPTION 'Falta instalar la configuración Autumn.'; END IF;
END;
$activate$;
COMMIT;
SELECT public.get_prelude_autumn_offer();
