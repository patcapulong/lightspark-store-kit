# Build a Crypto Ecommerce Store with Spark Payments

Build a functional ecommerce store that accepts Bitcoin payments via Spark (Bitcoin L2). Customers browse products, add items to a cart, check out with a shipping address, and pay by scanning a Lightning invoice QR code.

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌───────────┐
│  Storefront  │────▶│  API Server   │────▶│  Database  │
│  (Frontend)  │◀────│  (Backend)    │◀────│           │
└─────────────┘     └──────┬───────┘     └───────────┘
                           │
                    ┌──────▼───────┐
                    │  Spark SDK    │
                    │  (Payments)   │
                    └──────────────┘
```

### Pages / Views

1. **Product catalog** — Grid of products with name, price (in sats), and image
2. **Product detail** — Full product info, variant selector (size/color), add-to-cart
3. **Cart** — Line items, quantities, total in sats, proceed to checkout
4. **Checkout** — Shipping form → payment screen with QR code → order confirmation

### Key Behaviors

- Cart is client-side (localStorage or state management). No login required to browse or add to cart.
- Prices are in satoshis (sats). Optionally show a USD equivalent.
- Payment uses Lightning invoices: the server creates an invoice, the client displays a QR code, and the server polls for payment confirmation.

## Database Schema

Four core tables. Use any SQL database (PostgreSQL recommended).

```sql
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
  spark_invoice_id text,       -- Spark request ID for payment polling
  payment_tx_id text,          -- set after payment confirms
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
```

## Spark Payment Integration

Install the Spark SDK:

```bash
npm install @buildonspark/spark-sdk
```

### 1. Wallet Initialization (Server-Side Only)

Create a singleton wallet instance. The mnemonic must NEVER be exposed to the browser.

```typescript
import { SparkWallet } from "@buildonspark/spark-sdk";

let wallet: SparkWallet | null = null;

async function getWallet(): Promise<SparkWallet> {
  if (wallet) return wallet;

  const result = await SparkWallet.initialize({
    mnemonicOrSeed: process.env.SPARK_WALLET_MNEMONIC,
    options: { network: "MAINNET" },
  });
  wallet = result.wallet;
  return wallet;
}
```

### 2. Create a Lightning Invoice

When a customer is ready to pay, create an invoice for the order total:

```typescript
async function createInvoice(amountSats: number, memo: string) {
  const wallet = await getWallet();
  const result = await wallet.createLightningInvoice({ amountSats, memo });
  return {
    encodedInvoice: result.invoice?.encodedInvoice ?? null, // BOLT11 string for QR code
    requestId: result.id ?? null, // save this to poll payment status
  };
}
```

### 3. Check Payment Status

Poll this on an interval (every 2-3 seconds) after showing the QR code:

```typescript
async function checkPayment(requestId: string) {
  const wallet = await getWallet();
  const request = await wallet.getLightningReceiveRequest(requestId);

  const isPaid =
    request?.status === "TRANSFER_COMPLETED" ||
    request?.status === "LIGHTNING_PAYMENT_RECEIVED";

  return { isPaid, request };
}
```

## Payment Flow

Implement these API endpoints:

### POST /api/orders — Create Order

1. Receive cart items and shipping info from the client
2. Look up product prices from the database (never trust client-side prices)
3. Calculate `total_sats`
4. Insert the order and order items into the database
5. Create a Spark Lightning invoice for `total_sats`
6. Save the Spark `requestId` on the order record (`spark_invoice_id`)
7. Return the order ID and `encodedInvoice` to the client

### POST /api/payments/verify — Check Payment

1. Receive `orderId` from the client
2. Look up the order and its `spark_invoice_id`
3. If order status is already `paid`, return `{ status: "paid" }`
4. Call `checkPayment(spark_invoice_id)`
5. If paid:
   - Update order status to `paid`
   - Save the transaction ID (`payment_tx_id`)
   - Decrement inventory for each order item's variant
   - Return `{ status: "paid" }`
6. Otherwise return `{ status: "pending" }`

### Client-Side Payment UI

1. After creating the order, display the `encodedInvoice` as a QR code
   - Use any QR library (e.g. `qrcode.react`, `qrcode`)
2. Show a "copy to clipboard" button for the invoice string
3. Poll `POST /api/payments/verify` every 2-3 seconds
4. When status is `paid`, show a confirmation screen and clear the cart

## Security Constraints

- **Wallet mnemonic**: Server-side environment variable only. Never send to the browser.
- **Invoice creation**: Server-side only. The client only receives the encoded invoice string.
- **Payment verification**: Server-side only. The client only receives `paid` or `pending`.
- **Price validation**: Always calculate totals from database prices, not from client-submitted values.
- **API keys / service keys**: Never expose database credentials or service role keys to the client.

## Environment Variables

```
SPARK_WALLET_MNEMONIC=<your 12 or 24 word mnemonic>
SPARK_NETWORK=MAINNET
DATABASE_URL=<your database connection string>
```

## Seed Data (Optional)

Bootstrap your store with sample products:

```sql
insert into products (slug, name, description, price_sats, price_usd_cents, image_url, category) values
  ('classic-tee', 'Classic Tee', 'Premium cotton tee with your logo.', 25000, 2500, '', 'apparel'),
  ('hoodie', 'Logo Hoodie', 'Heavyweight hoodie with embroidered logo.', 50000, 5000, '', 'apparel'),
  ('sticker-pack', 'Sticker Pack', 'Set of 6 die-cut vinyl stickers.', 5000, 500, '', 'accessories'),
  ('coffee-mug', 'Coffee Mug', 'Ceramic mug with wraparound print. 12oz.', 10000, 1000, '', 'accessories');

insert into product_variants (product_id, size, sku, inventory_count) values
  ((select id from products where slug = 'classic-tee'), 'S', 'TEE-S', 25),
  ((select id from products where slug = 'classic-tee'), 'M', 'TEE-M', 40),
  ((select id from products where slug = 'classic-tee'), 'L', 'TEE-L', 40),
  ((select id from products where slug = 'classic-tee'), 'XL', 'TEE-XL', 25),
  ((select id from products where slug = 'hoodie'), 'S', 'HOOD-S', 15),
  ((select id from products where slug = 'hoodie'), 'M', 'HOOD-M', 25),
  ((select id from products where slug = 'hoodie'), 'L', 'HOOD-L', 25),
  ((select id from products where slug = 'hoodie'), 'XL', 'HOOD-XL', 15);
```

## Reference Implementation

For a complete working example, see: https://github.com/nickytonline/lightspark-store

This plan was extracted from that codebase. It uses Next.js, Supabase, and the Spark SDK — but you can adapt the patterns to any framework and database.
