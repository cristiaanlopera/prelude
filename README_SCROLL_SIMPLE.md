Prelude Sets · scroll móvil simplificado

Al llegar a 5/5:
- se actualiza el bloque de selección;
- se esperan dos frames para que el DOM termine de pintar;
- se calcula la posición exacta dentro de #preludeSetModalBody;
- se asigna scrollTop directamente;
- no se usa smooth scroll;
- no se usan MutationObservers;
- no se hacen segundos intentos que puedan devolver el popup arriba.

Objetivo: máxima estabilidad en Safari/iPhone.
