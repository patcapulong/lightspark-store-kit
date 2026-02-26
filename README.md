# Spark Store Kit

Everything you need to build an ecommerce store that accepts Bitcoin payments via [Spark](https://www.sparkinfra.com/) (Bitcoin L2). Feed `PLAN.md` to your AI coding tool and it will generate a working store.

## What's in the kit

- **PLAN.md** — LLM-ready spec covering architecture, database schema, payment integration, and API endpoints
- **schema.sql** — Portable PostgreSQL schema for products, variants, orders, and order items
- **spark-reference.md** — Spark SDK patterns: wallet setup, invoice creation, payment verification

## Prerequisites

Before you start, you'll need:

1. **Node.js 18+**
2. **A Spark wallet mnemonic** — Generate one at [docs.sparkinfra.com](https://docs.sparkinfra.com) or via the Spark SDK
3. **A PostgreSQL database** — [Supabase](https://supabase.com), [Neon](https://neon.tech), [Railway](https://railway.app), or local Postgres all work

## How to use it

### With Cursor

1. Open Cursor
2. Start a new project
3. Open the Composer (Cmd+I)
4. Paste the contents of `PLAN.md`
5. Let Cursor build it

### With Claude, ChatGPT, or any LLM

1. Copy the contents of `PLAN.md`
2. Paste it into a new conversation
3. Ask it to build the store
4. Copy the generated code into your project

### With Bolt or v0

1. Copy the contents of `PLAN.md`
2. Paste as the initial prompt
3. Deploy when ready

## After generation

1. Run `schema.sql` against your database
2. Set your environment variables:
   ```
   SPARK_WALLET_MNEMONIC=<your mnemonic>
   SPARK_NETWORK=MAINNET
   DATABASE_URL=<your connection string>
   ```
3. Seed some products (sample data is included in `PLAN.md`)
4. Start the dev server and test a payment

## Reference implementation

See the full working store this kit was extracted from: [github.com/patcapulong/lightspark-store-kit](https://github.com/patcapulong/lightspark-store-kit)

## Links

- [Spark SDK on npm](https://www.npmjs.com/package/@buildonspark/spark-sdk)
- [Spark SDK on GitHub](https://github.com/buildonspark/spark-sdk)
- [Spark documentation](https://docs.sparkinfra.com)
