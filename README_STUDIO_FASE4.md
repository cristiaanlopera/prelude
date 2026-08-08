# Prelude Studio · Fase 4

Esta versión añade gestión real de **Catálogo, Precios y Stock** conectada a Supabase.

1. Ejecuta `Prelude_Studio_Fase4_Catalogo_Precios_Stock.sql` una sola vez en Supabase SQL Editor.
2. Publica el resto del proyecto en GitHub/Netlify.
3. En `/studio`, usa Catálogo para publicar/ocultar, Precios para editar importes y Stock para fijar el stock disponible en ml.

El stock vendido se calcula automáticamente a partir de pedidos con estado `delivered`, por lo que revertir un pedido entregado también devuelve esos ml al stock disponible.
