# Prelude Studio · Fase 6 — Estadísticas

Esta fase activa el módulo **Estadísticas** utilizando los datos reales ya disponibles en Supabase.

## Métricas
- Ingresos de pedidos entregados.
- Ticket medio.
- Clientes con compra y tasa de recurrencia.
- Decants y mililitros servidos.
- Perfumes más vendidos.
- Evolución mensual de ingresos.
- Distribución por estado de pedido.
- Tamaños más elegidos.
- Zonas de entrega.
- Clientes recurrentes.

Las métricas económicas se calculan exclusivamente con pedidos en estado **Entregado**.

## Supabase
No requiere un SQL nuevo: utiliza `admin_list_prelude_orders()` y `admin_list_customers()` creadas en fases anteriores.
