# PRELUDE — Autumn Discovery Set: compra y stock automático

**Fecha:** 2026-10-14  
**Estado:** preparado para revisión; **NO ejecutado en Supabase**, **NO desplegado en Netlify**.

## Decisión del usuario
Sin límite comercial de sets. El cliente puede comprar tantos como permita el stock real:
- 1 set = 20,00 € y **3 ml de cada uno** de los cinco perfumes.
- 2 sets = 40,00 € y **6 ml de cada uno**.
- Al registrar el pedido en Supabase se **reserva** ese volumen en el stock disponible de Studio y web.
- Al pasar de pendiente a entregado, NO se descuenta por segunda vez.
- Al cancelar, la reserva desaparece y los mililitros vuelven a estar disponibles.
- No tocar descuentos ni bonificaciones de otros Prelude Sets.

## Cómo funciona
La web (`index.html`) ya envía las cinco líneas con los IDs reales de catálogo,
`set_id=autumn-2026`, el mismo `set_instance` y total de **20,00 €**; evita el
envío por WhatsApp si el registro en Supabase falla.

La migración `Prelude_Autumn_2026_Oferta_Controlada_PENDIENTE.sql` valida en la base de datos
la composición, el precio, la disponibilidad y los reintentos antes de insertar el pedido.

La migración adicional **`Prelude_Autumn_Stock_Reserva_Automatica_PENDIENTE.sql`**
hace que el stock disponible de la web y de Studio reste también los 3 ml de
cada componente de los pedidos Autumn que están `pending`, `preparing` o `ready`.
Al cambiar a `delivered`, la reserva se sustituye automáticamente por el cómputo
de venta entregada que Prelude ya utiliza, por lo que el descuento ocurre UNA VEZ.
Al cambiar a `cancelled`, deja de contabilizarse.

No manipula a la baja el `stock_initial_ml` como si fuera un movimiento de venta;
conserva su significado de stock base. La operación de ajustar el stock disponible
en Studio se adapta para contabilizar las reservas pendientes.

## Comprobaciones previas indispensables, NO son límites comerciales
1. **Comprobar el esquema y guardar la definición vigente** de
   `get_prelude_catalog`, `admin_list_prelude_catalog`,
   `admin_set_prelude_catalog_stock`, `create_prelude_order`,
   `admin_update_prelude_order_status` y sus permisos/RLS.
   Los SQL existentes en este ZIP son **históricos** y quizá no coincidan con producción.
   La migración adicional se ha preparado basándose en esas versiones:
   **NO ejecutar sin comparar funciones reales**.
2. Completar las existencias físicas en Studio si faltan. La consulta que nos
   has enviado tiene `stock_initial_ml = NULL` para **Gris Charnel**, **La Nuit
   de L'Homme** y **Mercedes-Benz Club Black**. Por eso todavía no es posible
   ofrecer una compra protegida sin registrar los ml reales. El dato ≈60 ml
   de Gris Charnel es una estimación, NO una existencia exacta confirmada.
3. Revisar en entorno de pruebas las dos migraciones SQL, en este orden:
   - `Prelude_Autumn_2026_Oferta_Controlada_PENDIENTE.sql`
   - `Prelude_Autumn_Stock_Reserva_Automatica_PENDIENTE.sql`
4. Probar la reserva y reversión para un pedido de prueba autorizado, sin
   registrar ventas ficticias en producción: stock antes, pedido `pending`,
   `preparing`, `delivered`, cancelación y reintento del mismo `set_instance`.
5. Solo después activar la oferta en Supabase y publicar la web en una rama
   revisada, tras comprobar los aspectos legales y operativos pendientes.
   El SQL de oferta la crea con `active = false` por defecto.

## Cinco perfumes, IDs de catálogo comprobados en consulta aportada
- Gris Charnel: `22d3ba81-eab3-4f6b-ab8a-a6de229cd8db`
- Replica By The Fireplace: `b7cb2bbe-bb43-4eb5-bfd5-2cd54227ec24`
- La Nuit de L'Homme: `10a363f2-6768-4b57-b22b-db4a9b9f935e`
- Stronger With You: `6a9977e6-326f-42f5-b34b-64d04424da60`
- Mercedes-Benz Club Black: `06d9d432-aaf9-4f54-a5a2-eeab4fe89e69`

**Importante:** el registro oculto llamado `By The Fireplace` no forma parte del set.

## Pruebas de cálculo (esperado)
Stock disponible inicial A, vendido-entregado D, reservas pendientes R:
`disponible = max(0, A - D - R)`.
- Registrar 1 set: R aumenta 3 por perfume.
- Registrar 2 sets: R aumenta 6 por perfume.
- Cambiar pendiente → entregado: R baja 3 y D sube 3; saldo no cambia.
- Cancelar antes de entregar: R baja 3; saldo aumenta 3.

## Lo que no se ha hecho
- No se ha accedido ni ejecutado SQL en la base real.
- No se ha confirmado el stock físico de las cinco referencias.
- No se ha publicado el ZIP ni se ha probado una compra real.
- No se ha impuesto un máximo fijo de sets.
- No se han cambiado imágenes, diseño, impresión ni recompensas de otros sets.
