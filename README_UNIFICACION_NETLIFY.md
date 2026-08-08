# Prelude — sitio único en Netlify

Este proyecto contiene tanto la web pública (`index.html`) como Prelude Studio (`studio.html`).

Rutas:
- `/` → Prelude
- `/studio` → Prelude Studio

La ruta `/studio` se resuelve internamente a `/studio.html` mediante `netlify.toml`.

Recomendación:
1. Publicar únicamente este repositorio en el sitio principal de Netlify.
2. Verificar `/` y `/studio`.
3. Cuando ambos funcionen, dejar de usar el antiguo sitio `preludestudio.netlify.app` para evitar despliegues duplicados.
