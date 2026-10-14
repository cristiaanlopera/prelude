# PRELUDE — Corrección visual Autumn Discovery Set
Fecha: 14/10/2026
Estado: archivos preparados y comprobados localmente; NO desplegados.

Base: PRELUDE_Autumn_Composicion_Completa_Fondo_Restaurado_2026-10-14.zip.

## Cambios
- `index.html`: sustitución del bloque CSS `prelude-autumn-visual-approved`.
- Se elimina la costura vertical en la portada mediante un fundido suave del borde izquierdo de la composición.
- La composición existente se muestra ampliada e integrada en el fondo beige otoñal, sin difuminar Gris Charnel ni tapar el título.
- El precio (20,00 €), formato (5 × 3 ml) y disponibilidad otoñal se presentan en líneas distintas, con más aire y un leve efecto luminoso.
- En móvil la imagen se coloca debajo del texto sin distorsionarla.
- Se conserva el fondo cálido del pop-up y las tarjetas reversibles existentes.
- **NO se han generado, cambiado ni recompuesto las seis imágenes de `assets/autumn/`.**

## Verificaciones efectuadas
- Render del bloque en Chromium en escritorio (1280 y 1672 px) y móvil (390 px).
- Render del pop-up.
- Interacción comprobada localmente: abrir, girar una tarjeta y cerrar con Escape.
- Sintaxis JavaScript del modal válida.
- Integridad y rutas de los recursos en el ZIP.

## Pendiente antes de producción
- Revisar en Netlify Deploy Preview que el resto de la web y sus funciones no hayan sufrido regresiones.
- El Autumn Discovery Set sigue siendo una presentación informativa: compra, stock y pedidos en Studio/Supabase no se han activado.
- No sustituir datos de producción ni ejecutar scripts SQL como parte de esta actualización.

Para GitHub: descomprimir y subir los archivos del paquete respetando la estructura, preferiblemente en una rama de revisión.
