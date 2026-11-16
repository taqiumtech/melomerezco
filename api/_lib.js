// Utilidades compartidas: Flow + Supabase (REST con clave secreta).
// El guion bajo inicial hace que Vercel NO lo publique como endpoint.
const crypto = require('crypto');

const env = (...names) => { for (const n of names) if (process.env[n]) return process.env[n]; return ''; };

const FLOW_API_URL = (env('FLOW_API_URL') || 'https://sandbox.flow.cl/api').replace(/\/$/, '');
const FLOW_API_KEY = env('FLOW_API_KEY');
const FLOW_SECRET_KEY = env('FLOW_SECRET_KEY');
const SUPABASE_URL = env('MLM_SUPABASE_URL', 'SUPABASE_URL', 'NEXT_PUBLIC_SUPABASE_URL').replace(/\/$/, '');
const SUPABASE_ANON = env('MLM_SUPABASE_ANON_KEY', 'SUPABASE_ANON_KEY', 'NEXT_PUBLIC_SUPABASE_ANON_KEY', 'SUPABASE_PUBLISHABLE_KEY');
const SUPABASE_SECRET = env('MLM_SUPABASE_SERVICE_KEY', 'SUPABASE_SERVICE_ROLE_KEY', 'SUPABASE_SECRET_KEY');
const ORDER_PREFIX = 'MLM-';

// URL pública del sitio: variable SITE_URL o el dominio por el que entró la visita.
function siteUrl(req) {
  if (env('SITE_URL')) return env('SITE_URL').replace(/\/$/, '');
  const host = (req && (req.headers['x-forwarded-host'] || req.headers.host)) || '';
  return host ? 'https://' + host : '';
}

// Firma de Flow: parámetros ordenados alfabéticamente, nombre+valor sin separadores, HMAC-SHA256.
function flowSign(params) {
  const str = Object.keys(params).sort().map(k => k + String(params[k])).join('');
  return crypto.createHmac('sha256', FLOW_SECRET_KEY).update(str).digest('hex');
}

async function flowPost(path, params) {
  const all = Object.assign({ apiKey: FLOW_API_KEY }, params);
  all.s = flowSign(all);
  const r = await fetch(FLOW_API_URL + path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(all).toString(),
  });
  const data = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error('Flow ' + path + ' ' + r.status + ': ' + JSON.stringify(data));
  return data;
}

async function flowGet(path, params) {
  const all = Object.assign({ apiKey: FLOW_API_KEY }, params);
  all.s = flowSign(all);
  const r = await fetch(FLOW_API_URL + path + '?' + new URLSearchParams(all).toString());
  const data = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error('Flow ' + path + ' ' + r.status + ': ' + JSON.stringify(data));
  return data;
}

// Supabase REST con la clave secreta (salta RLS). Soporta claves nuevas (sb_secret_) y legacy (eyJ...).
async function sb(path, opts) {
  opts = opts || {};
  const headers = { apikey: SUPABASE_SECRET, 'Content-Type': 'application/json', Prefer: 'return=representation' };
  if (/^eyJ/.test(SUPABASE_SECRET)) headers.Authorization = 'Bearer ' + SUPABASE_SECRET;
  const r = await fetch(SUPABASE_URL + '/rest/v1/' + path, {
    method: opts.method || 'GET',
    headers: Object.assign(headers, opts.headers || {}),
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });
  const text = await r.text();
  const data = text ? JSON.parse(text) : null;
  if (!r.ok) throw new Error('Supabase ' + path + ' ' + r.status + ': ' + text);
  return data;
}

const FLOW_STATUS_MAP = { 1: 'pending', 2: 'paid', 3: 'rejected', 4: 'cancelled' };
const ADVANCED = ['paid', 'preparing', 'shipped', 'delivered'];

// Consulta el estado real en Flow, actualiza la orden y, si quedó pagada, descuenta stock.
async function syncOrderFromFlow(token) {
  const st = await flowGet('/payment/getStatus', { token });
  const commerceOrder = String(st.commerceOrder || '');
  const orderNumber = commerceOrder.replace(ORDER_PREFIX, '');
  if (!/^\d+$/.test(orderNumber)) throw new Error('commerceOrder inesperado: ' + commerceOrder);

  const rows = await sb('orders?order_number=eq.' + orderNumber + '&select=*');
  const order = rows && rows[0];
  if (!order) throw new Error('Orden no encontrada: ' + commerceOrder);

  if (Number(st.amount) !== Number(order.total)) {
    throw new Error('Monto no coincide en ' + commerceOrder + ': Flow=' + st.amount + ' orden=' + order.total);
  }
  if (ADVANCED.includes(order.status)) return order;

  const newStatus = FLOW_STATUS_MAP[st.status] || 'pending';
  const patch = {
    status: newStatus,
    flow_status: st.status,
    flow_order: st.flowOrder || order.flow_order,
    payment_media: (st.paymentData && st.paymentData.media) || order.payment_media,
  };
  if (newStatus === 'paid') patch.paid_at = new Date().toISOString();
  const upd = await sb('orders?id=eq.' + order.id, { method: 'PATCH', body: patch });
  if (newStatus === 'paid') await sb('rpc/apply_order_stock', { method: 'POST', body: { p_order: order.id } });
  return (upd && upd[0]) || Object.assign(order, patch);
}

function missingConfig() {
  const miss = [];
  if (!FLOW_API_KEY) miss.push('FLOW_API_KEY');
  if (!FLOW_SECRET_KEY) miss.push('FLOW_SECRET_KEY');
  if (!SUPABASE_URL) miss.push('MLM_SUPABASE_URL');
  if (!SUPABASE_SECRET) miss.push('MLM_SUPABASE_SERVICE_KEY');
  return miss;
}

module.exports = {
  flowPost, flowGet, sb, syncOrderFromFlow, missingConfig, siteUrl,
  SUPABASE_URL, SUPABASE_ANON, FLOW_API_URL, ORDER_PREFIX, ADVANCED, env,
};
