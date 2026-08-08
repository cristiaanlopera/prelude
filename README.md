# Prelude · Versión estable para Netlify

Esta versión mantiene CSS y JavaScript dentro de los propios HTML.

Archivos:
- index.html
- studio.html
- netlify.toml

Sube estos archivos a la raíz del repositorio y elimina las referencias anteriores
a carpetas css, js y data si pertenecían a la versión separada.

## Prelude Studio · Fase 1
- Nuevo Dashboard como pantalla inicial.
- Navegación preparada para 12 módulos: Dashboard, Pedidos, Clientes, Mi Colección Prelude, Códigos Prelude, Catálogo, Precios, Stock, Recompensas, Ranking, Museo Olfativo y Estadísticas.
- Métricas del Dashboard calculadas únicamente con datos reales ya disponibles en Supabase (clientes, gasto acumulado, obras descubiertas, códigos de hoy y códigos pendientes).
- Se conservan las funciones existentes de Códigos, Clientes y Ranking.
- Los módulos de fases posteriores se muestran como estructura preparada, sin simular funciones todavía no conectadas.

## Prelude Studio · Fase 2 — Pedidos

Esta versión añade registro real de pedidos en Supabase, gestión de estados desde Studio y generación de documentos PDF por pedido.

Antes de utilizar el módulo Pedidos, ejecuta `Prelude_Studio_Fase2_Pedidos.sql` en Supabase → SQL Editor.

Flujo: solicitud desde la web → pedido `Pendiente` en Studio → `Preparando` → `Listo` → `Entregado`. Si el pedido pertenece a una cuenta Prelude, al marcarlo como Entregado sus perfumes se incorporan a Mi Colección Prelude y se contabilizan gasto y Marcapáginas una única vez.

El PDF generado desde Studio es un documento de compra/recibo. No se presenta como factura fiscal hasta que se configuren los datos fiscales y la numeración legal correspondiente.
