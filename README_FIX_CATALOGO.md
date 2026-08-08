# Prelude · Fix Catálogo

Corrige dos problemas detectados tras la reconstrucción de Supabase:

1. Prelude Studio todavía intentaba subir imágenes al bucket antiguo `catalog-images`. Ahora usa el bucket canónico `prelude-media` y guarda imágenes en `catalog/...`.
2. El listado administrativo podía conservar/mostrar un perfume ya marcado con `deleted_at`, haciendo que un segundo intento de borrado devolviera `PRELUDE_CATALOG_PRODUCT_NOT_FOUND`. El listado excluye ahora los eliminados y el borrado es idempotente.

## Pasos

1. Ejecutar `Prelude_FIX_Catalogo_Storage_Eliminar.sql` una vez en Supabase.
2. Sustituir los archivos del proyecto/Netlify por esta versión corregida (especialmente `studio.html`).
3. Recargar Prelude Studio con Ctrl+F5.
4. Probar:
   - añadir perfume con imagen;
   - cambiar imagen de un perfume;
   - eliminar un perfume.
