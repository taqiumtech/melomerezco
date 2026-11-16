// /api/flow?action=create|confirm|return  — un solo endpoint para Flow.
const { flowPost, sb, syncOrderFromFlow, missingConfig, siteUrl, ORDER_PREFIX, ADVANCED, env } = require('./_lib');

const isEmail = s => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(s || ''));
const clean = (s, max) => String(s == null ? '' : s).trim().slice(0, max || 200);
const uuidRe = /^[0-9a-f-]{36}$/i;

function readToken(req) {
  let token = (req.body && req.body.token) || (req.query && req.query.token);
  if (!token && typeof req.body === 'string') token = new URLSearchParams(req.body).get('token');
  return token;
}

// POST desde el carrito. Recalcula todo desde Supabase: nunca confía en precios del navegador.
// Body: { customer:{name,email,phone,rut}, delivery:{type,address,comuna,region,notes}, items:[{variant_id, qty}] }
async function create(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método no permitido' });
  const miss = missingConfig();
  if (miss.length) return res.status(500).json({ error: 'La tienda aún no está conectada a pagos (faltan: ' + miss.join(', ') + ').' });

  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body) : (req.body || {});
    const c = body.customer || {}, d = body.delivery || {};
    const items = Array.isArray(body.items) ? body.items : [];

    const name = clean(c.name, 120), email = clean(c.email, 160).toLowerCase();
    const phone = clean(c.phone, 30), rut = clean(c.rut, 15);
    const dType = d.type === 'retiro' ? 'retiro' : 'despacho';
    const address = clean(d.address, 200), comuna = clean(d.comuna, 80), region = clean(d.region, 80), notes = clean(d.notes, 500);

    if (!name) return res.status(400).json({ error: 'Ingresa tu nombre.' });
    if (!isEmail(email)) return res.status(400).json({ error: 'Ingresa un correo válido.' });
    if (dType === 'despacho' && (!address || !comuna)) return res.status(400).json({ error: 'Ingresa dirección y comuna para el despacho.' });
    if (!items.length || items.length > 30) return res.status(400).json({ error: 'Tu carrito está vacío.' });

    const ids = [...new Set(items.map(i => String(i.variant_id || '')).filter(id => uuidRe.test(id)))];
    if (!ids.length) return res.status(400).json({ error: 'Tu carrito está vacío.' });
    const vars = await sb('product_variants?id=in.(' + ids.join(',') + ')&select=id,talla,color,stock,product:products(id,name,price,active)');
    const byId = {}; (vars || []).forEach(v => { byId[v.id] = v; });

    const lines = [];
    for (const it of items) {
      const v = byId[String(it.variant_id)];
      const qty = Math.max(1, Math.min(10, parseInt(it.qty, 10) || 1));
      if (!v || !v.product || !v.product.active) return res.status(400).json({ error: 'Una prenda del carrito ya no está disponible. Actualiza la página.' });
      if (v.stock < qty) return res.status(409).json({ error: v.product.name + ' talla ' + v.talla + (v.stock ? ': solo quedan ' + v.stock + '.' : ' está agotada.') });
      const unit = Math.round(Number(v.product.price) || 0);
      if (unit <= 0) return res.status(400).json({ error: v.product.name + ' no tiene precio configurado.' });
      lines.push({ product_id: v.product.id, variant_id: v.id, product_name: v.product.name, talla: v.talla, color: v.color || null, unit_price: unit, qty, subtotal: unit * qty });
    }

    const subtotal = lines.reduce((a, l) => a + l.subtotal, 0);
    const shipping = dType === 'despacho' ? (parseInt(env('SHIPPING_COST') || '0', 10) || 0) : 0;
    const total = subtotal + shipping;

    const created = await sb('orders', {
      method: 'POST',
      body: {
        customer_name: name, email, phone: phone || null, rut: rut || null,
        delivery_type: dType,
        address: dType === 'despacho' ? address : null,
        comuna: dType === 'despacho' ? comuna : null,
        region: dType === 'despacho' ? (region || null) : null,
        notes: notes || null, subtotal, shipping_cost: shipping, total, status: 'pending',
      },
    });
    const order = created[0];
    await sb('order_items', { method: 'POST', body: lines.map(l => Object.assign({ order_id: order.id }, l)) });

    const site = siteUrl(req);
    const commerceOrder = ORDER_PREFIX + order.order_number;
    const units = lines.reduce((a, l) => a + l.qty, 0);
    const subject = (lines.length === 1 ? 'Me lo merezco · ' + lines[0].product_name : 'Me lo merezco · Pedido ' + commerceOrder + ' (' + units + ' prendas)').slice(0, 120);

    const flow = await flowPost('/payment/create', {
      commerceOrder, subject, currency: 'CLP', amount: total, email,
      paymentMethod: 9, // 9 = todos los medios activos en tu cuenta Flow
      urlConfirmation: site + '/api/flow?action=confirm',
      urlReturn: site + '/api/flow?action=return',
    });
    await sb('orders?id=eq.' + order.id, { method: 'PATCH', body: { flow_token: flow.token, flow_order: flow.flowOrder } });

    return res.status(200).json({ order_number: order.order_number, commerce_order: commerceOrder, total, payment_url: flow.url + '?token=' + flow.token });
  } catch (err) {
    console.error('flow-create error:', err);
    return res.status(500).json({ error: 'No se pudo iniciar el pago. Intenta de nuevo en un momento.' });
  }
}

// urlConfirmation: Flow avisa desde sus servidores. Se consulta el estado firmado; no se confía en el body.
async function confirm(req, res) {
  if (req.method !== 'POST') return res.status(405).send('Method not allowed');
  if (missingConfig().length) return res.status(500).send('config');
  try {
    const token = readToken(req);
    if (!token) return res.status(400).send('token requerido');
    const order = await syncOrderFromFlow(token);
    console.log('flow-confirm', ORDER_PREFIX + order.order_number, order.status);
    return res.status(200).send('OK');
  } catch (err) {
    console.error('flow-confirm error:', err);
    return res.status(500).send('error'); // Flow reintenta
  }
}

// urlReturn: la compradora vuelve (POST con token) → redirige a la tienda con el resultado.
async function ret(req, res) {
  const site = siteUrl(req);
  const go = qs => { res.statusCode = 303; res.setHeader('Location', site + '/?' + qs); res.end(); };
  if (missingConfig().length) return go('pago=error');
  try {
    const token = readToken(req);
    if (!token) return go('pago=error');
    const order = await syncOrderFromFlow(token);
    const n = encodeURIComponent(ORDER_PREFIX + order.order_number);
    if (ADVANCED.includes(order.status)) return go('pago=ok&orden=' + n);
    if (order.status === 'pending') return go('pago=pendiente&orden=' + n);
    return go('pago=rechazado&orden=' + n);
  } catch (err) {
    console.error('flow-return error:', err);
    return go('pago=error');
  }
}

const handlers = { create, confirm, return: ret };

module.exports = async function handler(req, res) {
  const h = handlers[String((req.query && req.query.action) || '')];
  if (!h) return res.status(404).json({ error: 'Acción no válida' });
  return h(req, res);
};
