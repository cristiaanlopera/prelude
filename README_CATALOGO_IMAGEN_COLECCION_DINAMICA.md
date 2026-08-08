# Prelude · Catálogo dinámico

Esta versión añade:

- Botón **Subir imagen** en Prelude Studio → Catálogo, usando Supabase Storage.
- Los perfumes en estado **Próximamente** u **Oculto** pueden crearse sin precios.
- Para pasar un perfume a **Publicado**, los cuatro precios (2, 3, 5 y 10 ml) deben estar completos.
- Cada perfume nuevo crea automáticamente su ficha en el Museo / Mi Colección Prelude.
- El total de obras deja de ser fijo: aumenta automáticamente cuando se incorporan nuevas fragancias.
- Desde Catálogo también se puede sustituir la imagen de un perfume ya existente.

Antes de publicar, ejecutar una sola vez en Supabase:
`Prelude_Catalogo_SubirImagen_Coleccion_Dinamica.sql`
