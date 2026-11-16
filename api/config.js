// GET /api/config → datos PÚBLICOS para el navegador (URL de Supabase y clave publicable).
// La clave publicable/anon es pública por diseño: la seguridad la ponen las políticas RLS.
const { SUPABASE_URL, SUPABASE_ANON, FLOW_API_URL, env } = require('./_lib');

module.exports = function handler(req, res) {
  res.setHeader('Cache-Control', 'public, max-age=300');
  res.status(200).json({
    supabaseUrl: SUPABASE_URL || null,
    supabaseKey: SUPABASE_ANON || null,
    flowSandbox: /sandbox/.test(FLOW_API_URL),
    whatsapp: env('WHATSAPP_NUMBER') || null,
    instagram: env('INSTAGRAM_USER') || null,
    shippingCost: parseInt(env('SHIPPING_COST') || '0', 10) || 0,
  });
};
