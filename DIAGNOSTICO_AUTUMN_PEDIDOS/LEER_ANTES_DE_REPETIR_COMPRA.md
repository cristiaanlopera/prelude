# Prelude · Diagnóstico de un pedido Autumn rechazado
Fecha: 14/10/2026.

## Qué está hecho
- Se ha modificado exclusivamente el mensaje de error en `index.html`.
- Ahora el aviso muestra `error.code` y `error.message` de Supabase.
- El bloqueo del envío por WhatsApp sigue intacto si no se confirma un pedido.
- No se ha alterado el precio de 20 €, el diseño, la composición, los triggers ni la reserva de stock.
- El SQL de diagnóstico solo lee los pedidos Autumn y no incluye datos personales.

## Qué hacer
1. **Antes de repetir la compra**, en Supabase > SQL Editor ejecuta
   `COMPROBAR_SI_EL_PEDIDO_AUTUMN_SE_REGISTRO_SOLO_LECTURA.sql`.
2. Si aparece algún pedido correspondiente al intento fallido, NO lo repitas:
   revisa primero su estado en Studio para evitar duplicados.
3. Si no aparece el intento, publica la web con el nuevo `index.html`
   (mantén los demás archivos del ZIP si necesitas reemplazar la web completa).
4. Prueba una vez con un pedido controlado, sin cobrarlo ni prepararlo.
5. Envíame **código** y **motivo** del error exacto si lo hay.
6. Tras la prueba verifica Studio y stock con `get_prelude_autumn_offer()`.
   Cancela solo por el flujo previsto de Studio si hay que revertir la reserva.

## Estado
Modificación local revisada. No se ha desplegado ni probado frente a Supabase real.
La consulta no permite ver pedidos que se registraron sin la marca `set_id` de Autumn.
Este parche diagnostica la causa; no se afirma que resuelva un rechazo aún desconocido.

## Nota de seguridad
No compartas nombres/teléfonos de clientes ni claves de Supabase. No vuelvas a ejecutar
la migración ni el SQL de activación: ya constaba `ready=true`, `active=true`.
