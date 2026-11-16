# ¡Me lo merezco! · Tienda de moda

Sitio estático (`index.html`, `admin.html`) + funciones de Vercel en `/api` para pagos con **Flow** y datos en **Supabase**.

- `/` → tienda: categorías, prendas con fotos y videos, tallas con stock, guía de tallas, carrito y pago con Flow.
- `/admin` → panel: subir prendas, fotos y videos, tallas/stock, categorías y pedidos.
- `/api/config` → entrega al navegador la URL y la clave **pública** de Supabase.
- `/api/flow?action=create|confirm|return` → crea el pago, recibe la confirmación de Flow y devuelve a la clienta a la tienda. Al confirmarse el pago se descuenta el stock.

## Puesta en marcha

1. **Supabase**: crea un proyecto para Me lo merezco y en *SQL Editor* corre `sql/01_schema.sql`.
2. **Tu usuario admin**: en *Authentication → Users → Add user* crea tu correo y contraseña (marca *Auto Confirm*). Luego corre `sql/02_admin.sql` con tu correo.
3. **Variables en Vercel** (proyecto `melomerezco` → Settings → Environment Variables):

| Variable | Valor |
|---|---|
| `MLM_SUPABASE_URL` | URL del proyecto (Settings → API) |
| `MLM_SUPABASE_ANON_KEY` | clave *publishable* / *anon* |
| `MLM_SUPABASE_SERVICE_KEY` | clave *secret* / *service_role* (¡secreta!) |
| `FLOW_API_KEY` | API Key de Flow |
| `FLOW_SECRET_KEY` | Secret Key de Flow (¡secreta!) |
| `FLOW_API_URL` | `https://sandbox.flow.cl/api` para pruebas, `https://www.flow.cl/api` en producción |
| `SHIPPING_COST` | opcional: costo fijo de despacho en CLP (vacío o 0 = "por pagar") |
| `WHATSAPP_NUMBER` | opcional: ej. `56912345678` (muestra el botón de WhatsApp) |
| `INSTAGRAM_USER` | opcional: usuario de Instagram |
| `SITE_URL` | opcional: dominio final, ej. `https://melomerezco.cl` |

4. Vuelve a desplegar (Deployments → Redeploy).

Mientras no haya Supabase configurado, la tienda muestra prendas de **ejemplo** y el pago queda desactivado.

## Fotos y videos
Se suben desde `/admin` al bucket `productos` de Supabase Storage. Las fotos se reducen solas a 1600 px. En el plan gratis de Supabase cada archivo puede pesar hasta 50 MB y el total es 1 GB: usa videos cortos (10–20 s) en MP4.

## Guía de tallas
Las medidas están en `index.html` (constante `GUIDES`). Cada prenda elige qué guía mostrar y puede tener sus propias medidas en el campo *Medidas de la prenda*.
