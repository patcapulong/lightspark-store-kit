# Spark SDK — Payment Integration Reference

The Spark SDK (`@buildonspark/spark-sdk`) lets you accept Bitcoin payments via Lightning invoices. Three patterns cover the full payment flow.

## Install

```bash
npm install @buildonspark/spark-sdk
```

## 1. Wallet Initialization

Create a singleton on the server. The mnemonic must never be exposed to the browser.

```typescript
import { SparkWallet } from "@buildonspark/spark-sdk";

let wallet: SparkWallet | null = null;

async function getWallet(): Promise<SparkWallet> {
  if (wallet) return wallet;

  const result = await SparkWallet.initialize({
    mnemonicOrSeed: process.env.SPARK_WALLET_MNEMONIC,
    options: { network: "MAINNET" }, // or "REGTEST" for development
  });
  wallet = result.wallet;
  return wallet;
}
```

**Notes:**
- `mnemonicOrSeed` accepts a 12 or 24-word BIP39 mnemonic string
- The wallet object is stateful — reuse the singleton across requests
- `network` must match your wallet's network: `"MAINNET"` for production, `"REGTEST"` for local development

## 2. Create a Lightning Invoice

Generate a BOLT11 invoice for the customer to pay:

```typescript
async function createInvoice(amountSats: number, memo: string) {
  const wallet = await getWallet();
  const result = await wallet.createLightningInvoice({ amountSats, memo });

  return {
    encodedInvoice: result.invoice?.encodedInvoice ?? null,
    requestId: result.id ?? null,
  };
}
```

**Returns:**
- `encodedInvoice` — BOLT11 string. Render this as a QR code for the customer.
- `requestId` — Spark request ID (e.g. `"SparkLightningReceiveRequest:019c9742-..."`). Save this on the order record to poll for payment status.

## 3. Check Payment Status

Poll this after displaying the QR code. Recommended interval: every 2-3 seconds.

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

**Status values that indicate payment is complete:**
- `"TRANSFER_COMPLETED"` — Spark transfer confirmed
- `"LIGHTNING_PAYMENT_RECEIVED"` — Lightning payment received

Any other status means the payment is still pending.

## Full Payment Flow

```
Client                          Server                          Spark
  │                               │                               │
  │  POST /api/orders             │                               │
  │  {items, shipping}            │                               │
  │──────────────────────────────▶│                               │
  │                               │  createLightningInvoice()     │
  │                               │──────────────────────────────▶│
  │                               │◀──────────────────────────────│
  │                               │  {encodedInvoice, requestId}  │
  │  {orderId, invoice}           │                               │
  │◀──────────────────────────────│                               │
  │                               │                               │
  │  Display QR code              │                               │
  │  Customer scans & pays        │                               │
  │                               │                               │
  │  POST /api/payments/verify    │                               │
  │  {orderId} (poll every 3s)    │                               │
  │──────────────────────────────▶│                               │
  │                               │  getLightningReceiveRequest() │
  │                               │──────────────────────────────▶│
  │                               │◀──────────────────────────────│
  │                               │  {status}                     │
  │  {status: "paid"}             │                               │
  │◀──────────────────────────────│                               │
  │                               │                               │
  │  Show confirmation            │                               │
```
