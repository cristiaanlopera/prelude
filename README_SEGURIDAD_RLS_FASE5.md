# Seguridad RLS · Fase 5

Esta versión activa Row Level Security en:

- `public.prelude_reward_settings`
- `public.prelude_museum_works`

El acceso directo desde `anon` y `authenticated` queda bloqueado. La web pública lee únicamente mediante las RPC `get_prelude_reward_settings()` y `get_prelude_museum_works()`. Las funciones de Prelude Studio verifican que `auth.uid()` exista en `public.prelude_admins`.

Ejecuta `Prelude_Studio_Fase5_Recompensas_Ranking_Museo.sql` en Supabase SQL Editor. Si las tablas ya existían por una ejecución previa, el script también activa RLS sobre ellas.
