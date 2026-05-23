# Error handling

A single, layered pattern that works across services, tRPC procedures, route handlers, and the client.

## The domain error hierarchy

```ts
// src/server/lib/errors.ts
import "server-only";

export class DomainError extends Error {
  constructor(message: string) {
    super(message);
    this.name = this.constructor.name;
  }
}

export class ForbiddenError extends DomainError {}     // 403
export class NotFoundError extends DomainError {}      // 404
export class ConflictError extends DomainError {}      // 409 — state-machine violations, duplicate keys
export class ValidationError extends DomainError {}    // 400 — semantic, not schema-shape
export class ExternalServiceError extends DomainError {} // 502 — third-party failed
```

One class per HTTP status code that the service might want to signal. Add new ones rarely — most things fit into the five above.

## Throwing from services

Services throw domain errors. They never set HTTP status codes or return error responses.

```ts
async award(userId: string, rfqId: string) {
  await requirePermission(userId, "rfqs:write");
  const rfq = await db.rfq.findUnique({ where: { id: rfqId } });
  if (!rfq) throw new NotFoundError(`RFQ ${rfqId} not found`);
  if (rfq.status !== "open") throw new ConflictError(`Cannot award RFQ in status ${rfq.status}`);
  // ...
}
```

## Catching in tRPC

The tRPC error formatter (in `src/server/api/trpc.ts`) maps domain errors to tRPC codes:

```ts
const t = initTRPC.context<Context>().create({
  transformer: superjson,
  errorFormatter({ shape, error }) {
    const cause = error.cause;
    if (cause instanceof ForbiddenError) shape.data.code = "FORBIDDEN";
    else if (cause instanceof NotFoundError) shape.data.code = "NOT_FOUND";
    else if (cause instanceof ConflictError) shape.data.code = "CONFLICT";
    else if (cause instanceof ValidationError) shape.data.code = "BAD_REQUEST";
    return {
      ...shape,
      data: {
        ...shape.data,
        zodError: cause instanceof ZodError ? cause.flatten() : null,
      },
    };
  },
});
```

The client receives a typed `TRPCClientError` whose `.data.code` reflects the status. No try/catch in the router.

## Catching in route handlers

The `toApiError` helper does the equivalent mapping for HTTP:

```ts
// src/server/lib/errors.ts
export function toApiError(err: unknown): Response {
  if (err instanceof ZodError) return Response.json(
    { error: "Invalid input", details: err.flatten() }, { status: 400 }
  );
  if (err instanceof ForbiddenError) return Response.json({ error: err.message }, { status: 403 });
  if (err instanceof NotFoundError) return Response.json({ error: err.message }, { status: 404 });
  if (err instanceof ConflictError) return Response.json({ error: err.message }, { status: 409 });
  if (err instanceof ValidationError) return Response.json({ error: err.message }, { status: 400 });
  if (err instanceof ExternalServiceError) return Response.json({ error: err.message }, { status: 502 });

  logger.error({ err }, "unhandled API error");
  return Response.json({ error: "Internal error" }, { status: 500 });
}
```

Every route handler wraps its body in `try { ... } catch (err) { return toApiError(err); }`. Boilerplate, but very small and very consistent.

## On the client

```tsx
const create = api.customer.create.useMutation({
  onError: (err) => {
    if (err.data?.code === "CONFLICT") {
      toast.error("That customer already exists.");
      return;
    }
    if (err.data?.zodError) {
      toast.error("Please fix the form errors.");
      return;
    }
    toast.error("Something went wrong. Try again.");
  },
});
```

Cases the UI cares about get specific messages; the fallback handles everything else. Don't try to enumerate every possible error — handle the ones the user can act on.

## What to put in `console.error` / `logger.error`

Nothing for expected domain errors. They're not bugs — they're normal control flow. Logging every 403 to Sentry creates noise that hides real issues.

Log:
- Unhandled errors (the fallthrough in `toApiError`).
- External service failures (Resend down, S3 timeout).
- State that shouldn't be possible (an "impossible" `else` branch reached).

## What NEVER goes in error messages

- Stack traces returned to the client. Surface a generic message; the stack lives in server logs (and Sentry if configured).
- Database details (`relation "..." does not exist`). Always wrap in a domain error before it escapes the service.
- Secrets, tokens, PII. Pino's `redact` config should strip these from logs too; double-check the catch-all logger isn't dumping `req.headers`.

## The principle

The service knows what went wrong in business terms (`NotFoundError`, `ConflictError`).
The delivery layer translates that into the transport's vocabulary (tRPC code, HTTP status).
The client translates the transport into something the user can act on (toast, inline message, redirect).

Each layer owns its own translation. None of them try to do two layers' jobs.
