-- Crypto Store — Database Schema
-- Standard PostgreSQL. Works with Supabase, Neon, Railway, or any Postgres host.

-- Products
create table products (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  description text not null default '',
  price_sats integer not null,
  price_usd_cents integer not null default 0,
  image_url text not null default '',
  category text not null default 'general',
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

-- Product variants (sizes, colors, etc.)
create table product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  size text,
  color text,
  sku text not null,
  inventory_count integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Orders
create table orders (
  id uuid primary key default gen_random_uuid(),
  user_email text,
  status text not null default 'pending'
    check (status in ('pending', 'paid', 'fulfilled', 'cancelled')),
  total_sats integer not null,
  spark_invoice_id text,
  payment_tx_id text,
  shipping_name text not null,
  shipping_address jsonb not null,
  created_at timestamptz not null default now()
);

-- Order line items
create table order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  product_id uuid not null references products(id),
  variant_id uuid references product_variants(id),
  quantity integer not null,
  price_sats integer not null,
  created_at timestamptz not null default now()
);

-- Indexes
create index idx_products_slug on products(slug);
create index idx_orders_status on orders(status);
create index idx_product_variants_product_id on product_variants(product_id);
create index idx_order_items_order_id on order_items(order_id);
