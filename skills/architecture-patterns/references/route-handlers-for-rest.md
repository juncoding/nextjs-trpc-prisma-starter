# Route handlers — when REST instead of tRPC

The default delivery layer for app data is tRPC. **Reach for a route handler only when** one of these conditions holds:

| Condition | Example |
|---|---|
| Caller is not a TS client | Stripe webhook, generic third-party REST consumer, curl-driven cron |
| Streaming binary response | PDF export, Excel download, CSV stream |
| File upload | Multipart form data, presigned S3 endpoints |
| External-facing API contract | "Customers will hit `/api/v1/orders` directly" |
| MCP entry point | `/api/mcp` |
| Webhook with signature verification | Resend, Svix, Stripe, Slack |
| Health / readiness probe | `/api/health` |

Everything else goes through tRPC.

## The shape

```ts
// src/app/api/v1/orders/[id]/route.ts
import { NextRequest } from "next/server";
import { requireSession } from "@/server/auth/session";
import { orderService } from "@/server/modules/order/order.service";
import { toApiError } from "@/server/lib/errors";

export async function GET(_req: NextRequest, { params }: { params: { id: string } }) {
  try {
    const session = await requireSession();
    const order = await orderService.findById(session.user.id, params.id);
    if (!order) return Response.json({ error: "Not found" }, { status: 404 });
    return Response.json(order);
  } catch (err) {
    return toApiError(err);
  }
}
```

## Rules

### Same service, same permission

The route handler calls the same service method that tRPC would. `requireSession()` extracts the session; the service's `requirePermission` enforces the scope.

### `toApiError(err)` maps errors to HTTP

```ts
// src/server/lib/errors.ts
export function toApiError(err: unknown): Response {
  if (err instanceof ZodError) {
    return Response.json({ error: "Invalid input", details: err.flatten() }, { status: 400 });
  }
  if (err instanceof ForbiddenError) {
    return Response.json({ error: err.message }, { status: 403 });
  }
  if (err instanceof NotFoundError) {
    return Response.json({ error: err.message }, { status: 404 });
  }
  if (err instanceof ConflictError) {
    return Response.json({ error: err.message }, { status: 409 });
  }
  // Log unknown errors with the request id so they're findable.
  logger.error({ err }, "unhandled API error");
  return Response.json({ error: "Internal error" }, { status: 500 });
}
```

One helper, used by every route handler. Don't reinvent per file.

### Versioning external-facing routes

Use `/api/v1/...` for routes intended for third parties or long-lived integrations. Internal routes (MCP, webhooks, health) don't need a version prefix — they're inside the same release boundary as the rest of the app.

### Webhooks: verify the signature first

```ts
// src/app/api/webhooks/resend/route.ts
import { Webhook } from "svix";

export async function POST(req: NextRequest) {
  const body = await req.text();                       // raw body for signature
  const wh = new Webhook(env.RESEND_WEBHOOK_SECRET);
  let event;
  try {
    event = wh.verify(body, Object.fromEntries(req.headers));
  } catch {
    return Response.json({ error: "Invalid signature" }, { status: 401 });
  }
  await emailService.handleWebhook(event);
  return Response.json({ ok: true });
}
```

Verification first, business logic second. Always.

### Streaming

```ts
// src/app/api/exports/customers.csv/route.ts
export async function GET(req: NextRequest) {
  const session = await requireSession();
  const stream = await customerService.streamAllAsCsv(session.user.id);
  return new Response(stream, {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="customers-${Date.now()}.csv"`,
    },
  });
}
```

`stream` is a `ReadableStream<Uint8Array>`. The service constructs it; the route handler just sets headers and returns.

## Testing route handlers

Route handlers are plain async functions — call them directly in tests:

```ts
import { GET } from "@/app/api/v1/orders/[id]/route";

it("returns 404 for missing order", async () => {
  const res = await GET(
    new Request("http://localhost/api/v1/orders/x"),
    { params: { id: "x" } }
  );
  expect(res.status).toBe(404);
});
```

You can also reach them via supertest if you spin up the Next.js dev server, but for most cases the direct-call approach is faster and enough.

## When you're tempted to add a REST route just for testing

Don't. Use the tRPC `createCaller` instead — it's typed, fast, and doesn't add a public surface you'll need to maintain forever.

REST routes are commitments. Every one you add is a contract you can't break without versioning. Reach for them only when the alternative is worse.
