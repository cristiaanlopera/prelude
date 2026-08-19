# Prelude Sets · fase funcional

## Antes de desplegar
Ejecuta `Prelude_Sets_Funcionales.sql` en Supabase.

## Prelude Studio
Prelude Sets está dentro del grupo Colección.
Cada Set permite:
- Activar/desactivar.
- Editar descuento.
- Editar Marcapáginas extra.
- Elegir 5 perfumes en Discovery, Journey y Curator.
- Simular rentabilidad con costes reales de 2 ml.
- Guardar la configuración en Supabase.
The Five y The Match son dinámicos; sus selectores en Studio sirven para simular.

## Web pública
- La web lee la configuración de Sets desde Supabase.
- The Five permite elegir 5 perfumes diferentes.
- The Match usa las 5 mejores afinidades del asesor olfativo.
- Discovery/Journey/Curator usan los 5 perfumes guardados en Studio.
- Se valida stock de 2 ml antes de añadir el Set.
- El descuento queda incluido en el precio de los 5 artículos.
- Un descuento porcentual de recompensa solo se aplica a productos normales, no vuelve a descontar los Sets.
- El carrito muestra el bonus de Marcapáginas.
- WhatsApp identifica el Set.
- Al marcar el pedido como entregado, Supabase suma los Marcapáginas normales + el bonus de cada Set una sola vez.
- Si el pedido deja de estar entregado, ese bonus también se revierte.
