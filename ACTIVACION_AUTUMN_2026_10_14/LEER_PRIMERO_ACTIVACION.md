# Prelude · Autumn Discovery Set — activación comercial 14/10/2026

**Estado: código y SQL preparados; SIN ejecutar en Supabase, SIN desplegar en Netlify.**

Estos archivos se han adaptado a cinco definiciones de funciones obtenidas mediante la consulta enviada el 14/10/2026. No hay acceso remoto a tu Supabase. No ejecutamos instrucciones por ti.

## Secuencia (sin límites comerciales de unidades)

1. Guarda una copia de la configuración y comprueba que el ZIP descargado es tu web aprobada.
2. En Supabase → SQL Editor → New query, abre `01_PRELUDE_AUTUMN_MIGRACION_STOCK.sql`, pega el contenido y ejecútalo. El archivo usa una transacción; si falla un comando no se aplica la migración.
3. Ejecuta `02_COMPROBAR_REFERENCIAS_Y_STOCK_SOLO_LECTURA.sql`.
4. Ajusta en **Prelude Studio** el número **real disponible** de ml de las cinco fragancias, sin inventar valores. En los datos recibidos hay tres `stock_initial_ml = NULL`: Gris Charnel, La Nuit de L'Homme y Club Black. Para Gris Charnel se estimaron ~60 ml, NO cifra confirmada. Los valores 100 y 156 previos eran iniciales, no necesariamente stock físico actual. Compara físicamente al introducir cifras.
5. Repite `02...` y confirma 5 filas, todos publicados, stock numérico >=3 ml, y función `get_prelude_autumn_offer` con `ready=true`. Corrige inconsistencias antes de activar.
6. Despliega en Netlify / GitHub los archivos del ZIP comercial actualizado manteniendo todos sus assets (sin cambiar secretos).
7. Ejecuta `03_ACTIVAR_COMPRA_SOLO_CON_STOCK_CONFIRMADO.sql`. Solo permite active=true con stock suficiente y 5 referencias correctamente configuradas.
8. Haz una compra de prueba **controlada** y comprueba en Studio el pedido y una reserva de 3 ml por cada uno de los 5 perfumes. Marca el pedido como cancelado y comprueba que el stock vuelve al nivel anterior. Comprueba entrega en otro pedido de prueba y que no se descuenta dos veces. Si las pruebas afectan al stock y al historial real, usa un entorno de pruebas o planifica reversión documentada.
9. Si surge un problema, usa `04_DESACTIVAR_SI_ES_NECESARIO.sql` para cerrar la oferta, sin afectar a otros Prelude Sets.

## Regla de stock
- 1 set = 5 perfumes x 3 ml = 15 ml, 20,00 €.
- Pedido abierto `pending` / `preparing` / `ready`: RESTA 3 ml de cada componente al disponible del catálogo y Studio.
- Pedido `delivered`: deja de restarse la reserva y pasa a contarse como entrega en la lógica histórica. NO se descuenta dos veces.
- Pedido `cancelled`: ni reserva ni venta entregada; se liberan los 3 ml correspondientes.
- Sin límite máximo artificial de sets. Si el stock es nulo/no verificado, el botón sigue desactivado.

## Notas de alcance
- Se preservan la firma y la lógica de `create_prelude_order` y de `admin_update_prelude_order_status`.
- Se preservan los campos originales de los tres RPC de stock recuperados de tu base de datos; únicamente se suma la reserva de Autumn en las cuentas.
- Hay protección contra envíos duplicados de la misma instancia de set y contra reintentos concurrentes de compra de Autumn.
- El SQL no acredita cumplimiento normativo de decants; verificar por separado antes de comercializar.
- No introducir claves `service_role` en `index.html`.
