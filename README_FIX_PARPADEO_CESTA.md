# Prelude · corrección del parpadeo al usar la cesta

Causa:
La web ejecutaba `renderProducts()` después de cada alta/baja de la cesta. Esto destruía y recreaba todas las tarjetas, reiniciando las animaciones de Podio Prelude y NOVEDAD.

Corrección:
- Añadir a cesta: solo se actualiza la cesta y los controles de stock.
- Eliminar de cesta: idem.
- Vaciar cesta: idem.
- Intentar superar stock: se actualizan controles sin reconstruir el catálogo.

Las tarjetas del catálogo permanecen en el DOM, por lo que las animaciones ya no se reinician con cada clic.
