# Actualización de integración comercial (14/10/2026)

**Leer antes:** `LEER_AUTUMN_COMPRA_Y_STOCK_2026-10-14.md`.
Sin límite comercial de unidades: la reserva es de 3 ml por perfume al registrarse el pedido, con reversión al cancelar y sin doble descuento al entregar. El archivo `Prelude_Autumn_Stock_Reserva_Automatica_PENDIENTE.sql` refleja las reservas también en el stock de Studio y de la web.

**Estado:** archivos preparados; sin acceso a Supabase ni despliegue. La consulta aportada tiene stock sin configurar en tres referencias. Antes de ejecutar SQL en producción, comparar las funciones vigentes con las definiciones históricas del paquete y probar en un entorno seguro.

---

# PRELUDE — Autumn Discovery Set · Integración comercial preparada
Fecha de preparación: **14/10/2026**.

## Resultado y estado
- **Preparado en archivos**: botón de compra dentro del pop-up, identificación del set como cinco artículos de 3 ml, suma de precio fijo de 20,00 €, comprobación de disponibilidad, protección del envío si falla Supabase, propuesta SQL de control de stock y precio.
- **Probado en simulación**: la compra queda deshabilitada sin activación de Supabase o con stock insuficiente; al activarse con datos válidos, añade 5 artículos y suma 20,00 €; no se repite la misma instancia.
- **No probado**: base de datos real, reserva de stock real, pedidos en producción, funcionamiento visual completo del navegador, Studio conectado.
- **No ejecutado**: ninguna migración SQL, ningún pedido, ningún despliegue de Netlify o GitHub.
- **NO listo para activar producción sin pasos posteriores**: la oferta se crea DESACTIVADA por defecto.

## Cambios en archivos
- `index.html`: mantiene el diseño visual aprobado y sus ilustraciones. Añade un botón de compra en el pop-up, validación de oferta vía RPC `get_prelude_autumn_offer`, comprobación de los cinco componentes por ID real de catálogo, protección ante fallo de creación de pedido, y los metadatos del set en los artículos.
- `Prelude_Autumn_2026_Oferta_Controlada_PENDIENTE.sql`: **propuesta** de migración revisable para Supabase. Añade configuración de oferta, composición ligada a IDs, función de lectura pública controlada, validación transaccional de los artículos del set, descuento de compromisos de stock y protección frente a solicitudes repetidas con el mismo `set_instance`. Inicialmente `active=false`.
- `PRELUDE_Autumn_Verificar_Catalogo_SOLO_LECTURA.sql`: consulta previa de referencia/coste/stock para ejecutar manualmente.
- Este documento y registro de decisión.
- `studio.html`, demás sets, imágenes, impresión, biblioteca, recompensas existentes y resto de archivos: sin modificar.

## Antes de tocar Supabase
1. Hacer copia de seguridad del esquema, funciones `create_prelude_order`/`get_prelude_catalog` y pedidos.
2. Ejecutar la consulta **solo de lectura** incluida y comprobar que devuelve las CINCO referencias exactas (un ID para cada combinación marca/nombre); verificar que By the Fireplace se llama en catálogo **Replica By The Fireplace** y descartar registros históricos sin precio.
3. Verificar existencia y significado actual de `prelude_catalog.id`, `stock_initial_ml`, `availability_status`, `price_3ml`, `prelude_orders.items`, `status` y sus políticas de acceso. Los SQL del ZIP describen versiones históricas, no una verificación del esquema en producción.
4. Confirmar stock utilizable de por lo menos 3 ml por referencia, frascos, consumibles, merma y embalaje. El coste compartido de 0,70 € observado antes NO confirma coste final del set.
5. Verificar requisitos legales y etiquetado de decants con documentación/asesoría pertinentes antes de habilitar ventas.
6. Confirmar tratamiento de marcapáginas (el paquete propone **0 bonus adicional** para la edición; los marcapáginas normales del pedido siguen las reglas actuales).

## Aplicación por fases
1. Crear una rama de revisión en GitHub y subir el contenido descomprimido. No subir el ZIP como archivo único.
2. Validar el `index.html` en una previsualización de Netlify: web habitual, modal Autumn, giro de tarjetas, cesta, checkout, móviles.
3. En una base de pruebas con estructura equivalente a producción, revisar y ejecutar `Prelude_Autumn_2026_Oferta_Controlada_PENDIENTE.sql`. Esta migración **no se ha ejecutado aquí**. Revisa sus permisos, funciones SECURITY DEFINER y triggers con un administrador.
4. Consultar `select public.get_prelude_autumn_offer();`. Solo si devuelve cinco componentes correctos, `ready=true`, precio `20.00` y stock comprobado, se puede continuar.
5. Con los requisitos legales, económicos y de seguridad resueltos, activar manualmente:
   `update public.prelude_autumn_offer_config set active=true, updated_at=now() where id='autumn-2026';`
6. Probar el registro de pedido en un entorno seguro y comprobar en Studio: artículos 3 ml, 20 € de subtotal del set, estado inicial, nombre/instancia del set, stock, puntos y no duplicación.
7. Publicar solo tras estas pruebas. Al terminar otoño, **desactivar manualmente** la oferta con `active=false`. No se han supuesto fechas automáticas de inicio o fin.

## Límites y riesgos conocidos
- **No hay acceso al Supabase real desde esta tarea**. No afirmar que el set esté comprable en producción.
- En este proyecto, la tarifa de preparación del pedido se calcula aparte: **20,00 € es el precio del set**, y el total del pedido puede ser superior si la tarifa aplica.
- El stock histórico de la web descuenta solo entregados. La nueva comprobación para Autumn descuenta todos los pedidos no cancelados. El trigger serializa pedidos Autumn entre sí, pero otras rutas históricas de pedido no adoptan ese bloqueo: revisar la operativa global si el volumen crece.
- El modelo general permite que la web envíe precios al RPC `create_prelude_order`; el trigger nuevo valida los artículos que lleven el ID de Autumn. **No corrige ni audita la validación general de precios de otros artículos.**
- El precio anterior y rentabilidad del set calculados en conversación son estimaciones, no una verificación actual de coste/beneficio neto ni autorización legal.
- Las identidades visuales de marcas se utilizan como referencia de productos originales; Prelude no reclama afiliación.

## Reversión
Desactivar `active=false`; retirar el botón restaurando el `index.html` del ZIP visual anterior. No borrar pedidos ni tablas de historial sin plan de reversión y verificación. No es necesario eliminar registros históricos para dejar de vender.

## Registro de decisión
14/10/2026 | Preparación y pruebas locales del código | Fuente: autorización del usuario en esta conversación y ZIP visual aprobado | Estado: **preparado / no desplegado** | Conserva la edición de 5 × 3 ml a 20,00 €, cinco perfumes y textos aprobados, solo otoño | Pendiente: ejecución SQL, stock, costes, conformidad legal, comprobación de Studio, pruebas end-to-end y despliegue.
