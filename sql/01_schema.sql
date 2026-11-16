-- ══════════════════════════════════════════════════════════════
-- ME LO MEREZCO · Esquema de la tienda
-- Correr completo en Supabase → SQL Editor. Es idempotente:
-- se puede volver a correr sin romper nada.
-- ══════════════════════════════════════════════════════════════

-- ── Administradoras/es del panel ──
create table if not exists public.admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

-- ── Categorías ──
create table if not exists public.categories (
  id         uuid primary key default gen_random_uuid(),
  slug       text unique not null,
  name       text not null,
  image_url  text,
  sort_order integer not null default 0,
  active     boolean not null default true
);

-- ── Productos ──
create table if not exists public.products (
  id            uuid primary key default gen_random_uuid(),
  slug          text unique not null,
  name          text not null,
  description   text,
  measures      text,                         -- medidas propias de la prenda (texto libre)
  price         integer not null check (price >= 0),          -- CLP
  compare_price integer check (compare_price is null or compare_price >= 0), -- precio "antes" (oferta)
  category_id   uuid references public.categories(id) on delete set null,
  size_guide    text not null default 'superior', -- superior | inferior | unica | calzado
  is_new        boolean not null default true,
  is_featured   boolean not null default false,  -- "Lo más vendido"
  active        boolean not null default true,
  sort_order    integer not null default 0,
  created_at    timestamptz not null default now()
);

-- ── Fotos y videos de cada prenda ──
create table if not exists public.product_media (
  id         uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  kind       text not null default 'image' check (kind in ('image','video')),
  url        text not null,
  path       text,                              -- ruta en Storage (para poder borrar el archivo)
  sort_order integer not null default 0
);

-- ── Tallas (y color opcional) con stock ──
create table if not exists public.product_variants (
  id         uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  talla      text not null,
  color      text,
  stock      integer not null default 0 check (stock >= 0),
  sort_order integer not null default 0
);

-- ── Órdenes (pagos con Flow) ──
create table if not exists public.orders (
  id             uuid primary key default gen_random_uuid(),
  order_number   bigserial unique,
  customer_name  text not null,
  email          text not null,
  phone          text,
  rut            text,
  delivery_type  text not null default 'despacho',   -- despacho | retiro
  address        text,
  comuna         text,
  region         text,
  notes          text,
  subtotal       integer not null default 0,
  shipping_cost  integer not null default 0,
  total          integer not null default 0,
  status         text not null default 'pending',    -- pending | paid | rejected | cancelled | preparing | shipped | delivered
  stock_applied  boolean not null default false,
  flow_token     text,
  flow_order     bigint,
  flow_status    integer,
  payment_media  text,
  paid_at        timestamptz,
  created_at     timestamptz not null default now()
);

create table if not exists public.order_items (
  id           uuid primary key default gen_random_uuid(),
  order_id     uuid not null references public.orders(id) on delete cascade,
  product_id   uuid,
  variant_id   uuid,
  product_name text not null,
  talla        text,
  color        text,
  unit_price   integer not null,
  qty          integer not null check (qty > 0),
  subtotal     integer not null
);

create index if not exists products_category_idx   on public.products(category_id);
create index if not exists media_product_idx        on public.product_media(product_id);
create index if not exists variants_product_idx     on public.product_variants(product_id);
create index if not exists orders_status_idx        on public.orders(status);
create index if not exists orders_flow_token_idx    on public.orders(flow_token);
create index if not exists order_items_order_idx    on public.order_items(order_id);

-- ── Descontar stock cuando una orden queda pagada (una sola vez) ──
create or replace function public.apply_order_stock(p_order uuid)
returns void language plpgsql security definer set search_path = public as $$
declare done boolean;
begin
  update public.orders set stock_applied = true
   where id = p_order and stock_applied = false and status = 'paid'
   returning true into done;
  if done is null then return; end if;
  update public.product_variants v
     set stock = greatest(0, v.stock - oi.qty)
    from public.order_items oi
   where oi.order_id = p_order and oi.variant_id = v.id;
end $$;
revoke all on function public.apply_order_stock(uuid) from public, anon, authenticated;

-- ══════════════ Seguridad (RLS) ══════════════
alter table public.admins            enable row level security;
alter table public.categories        enable row level security;
alter table public.products          enable row level security;
alter table public.product_media     enable row level security;
alter table public.product_variants  enable row level security;
alter table public.orders            enable row level security;
alter table public.order_items       enable row level security;

-- Catálogo: lectura pública de lo activo; escritura solo admins.
drop policy if exists cat_read   on public.categories;
drop policy if exists cat_admin  on public.categories;
create policy cat_read  on public.categories for select using (active or public.is_admin());
create policy cat_admin on public.categories for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists prod_read  on public.products;
drop policy if exists prod_admin on public.products;
create policy prod_read  on public.products for select using (active or public.is_admin());
create policy prod_admin on public.products for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists media_read  on public.product_media;
drop policy if exists media_admin on public.product_media;
create policy media_read  on public.product_media for select using (true);
create policy media_admin on public.product_media for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists var_read  on public.product_variants;
drop policy if exists var_admin on public.product_variants;
create policy var_read  on public.product_variants for select using (true);
create policy var_admin on public.product_variants for all using (public.is_admin()) with check (public.is_admin());

-- Admins: cada uno puede verse a sí mismo (para que el panel sepa si es admin).
drop policy if exists admins_self on public.admins;
create policy admins_self on public.admins for select using (user_id = auth.uid());

-- Órdenes: datos de compradoras NO públicos. Solo admins leen/actualizan.
-- Las crea /api/flow con la clave secreta (service role), que salta RLS.
drop policy if exists orders_admin on public.orders;
drop policy if exists items_admin  on public.order_items;
create policy orders_admin on public.orders      for all using (public.is_admin()) with check (public.is_admin());
create policy items_admin  on public.order_items for select using (public.is_admin());

-- ══════════════ Storage: fotos y videos ══════════════
insert into storage.buckets (id, name, public)
values ('productos', 'productos', true)
on conflict (id) do update set public = true;

drop policy if exists "productos lectura"  on storage.objects;
drop policy if exists "productos admin ins" on storage.objects;
drop policy if exists "productos admin upd" on storage.objects;
drop policy if exists "productos admin del" on storage.objects;
create policy "productos lectura"   on storage.objects for select using (bucket_id = 'productos');
create policy "productos admin ins" on storage.objects for insert with check (bucket_id = 'productos' and public.is_admin());
create policy "productos admin upd" on storage.objects for update using (bucket_id = 'productos' and public.is_admin());
create policy "productos admin del" on storage.objects for delete using (bucket_id = 'productos' and public.is_admin());

-- ══════════════ Categorías iniciales ══════════════
insert into public.categories (slug, name, image_url, sort_order) values
  ('palazzos',   'Palazzos',   '/assets/cat-palazzos.jpg', 1),
  ('jeans',      'Jeans',      '/assets/cat-jeans.jpg',    2),
  ('bodys',      'Bodys',      '/assets/cat-bodys.jpg',    3),
  ('tops',       'Tops crop',  '/assets/cat-tops.jpg',     4),
  ('vestidos',   'Vestidos',   null, 5),
  ('faldas',     'Faldas',     null, 6),
  ('accesorios', 'Accesorios', null, 7)
on conflict (slug) do nothing;
