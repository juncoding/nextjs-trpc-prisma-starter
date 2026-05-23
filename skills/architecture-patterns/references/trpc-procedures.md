# tRPC procedure pattern

## The shape

```ts
// src/server/api/routers/customer.ts
import { z } from "zod";
import { createTRPCRouter, protectedProcedure } from "../trpc";
import { customerService } from "@/server/modules/customer/customer.service";
import {
  CreateCustomerSchema,
  UpdateCustomerSchema,
  ListCustomersSchema,
} from "@/server/modules/customer/customer.schema";

export const customerRouter = createTRPCRouter({
  list: protectedProcedure
    .input(ListCustomersSchema)
    .query(({ ctx, input }) => customerService.list(ctx.session.user.id, input)),

  getById: protectedProcedure
    .input(z.object({ id: z.string() }))
    .query(({ ctx, input }) => customerService.findById(ctx.session.user.id, input.id)),

  create: protectedProcedure
    .input(CreateCustomerSchema)
    .mutation(({ ctx, input }) => customerService.create(ctx.session.user.id, input)),

  update: protectedProcedure
    .input(z.object({ id: z.string(), data: UpdateCustomerSchema }))
    .mutation(({ ctx, input }) =>
      customerService.update(ctx.session.user.id, input.id, input.data)
    ),
});
```

Then mount in `src/server/api/root.ts`:

```ts
import { customerRouter } from "./routers/customer";

export const appRouter = createTRPCRouter({
  customer: customerRouter,
  // ...
});
```

## Rules

### Routers are dumb pipes

The router does three things only:

1. Pick `publicProcedure` vs `protectedProcedure`.
2. Validate input via `.input(schema)`.
3. Call a service method, passing `ctx.session.user.id` as the first argument.

No business logic. No DB calls. If the router has more than three lines per procedure, it's doing too much.

### `query` for reads, `mutation` for writes

This isn't decorative — it controls HTTP method, batching, and React Query caching. Reads are GET-like and cacheable; writes are POST-like and invalidate caches.

### Reuse the module's Zod schemas

The same `CreateCustomerSchema` that the service uses is the one passed to `.input()`. This guarantees the contract between transport and business logic stays in sync.

### Errors propagate naturally

Service throws `ForbiddenError` → tRPC converts to `{ code: "FORBIDDEN" }`. The client receives a typed `TRPCClientError` whose `.data.code` is "FORBIDDEN". No try/catch in the router.

To get this mapping, define your domain errors in `src/server/lib/errors.ts` and add a thin handler in `src/server/api/trpc.ts`:

```ts
// src/server/lib/errors.ts
export class ForbiddenError extends Error {}
export class NotFoundError extends Error {}
export class ConflictError extends Error {}

// src/server/api/trpc.ts (inside errorFormatter)
if (error.cause instanceof ForbiddenError) shape.data.code = "FORBIDDEN";
if (error.cause instanceof NotFoundError) shape.data.code = "NOT_FOUND";
// etc.
```

See `error-handling.md` for the full pattern.

## Client-side usage

```tsx
// src/features/customers/customer-table.tsx
"use client";
import { api } from "@/lib/trpc-react";

export function CustomerTable() {
  const { data, isLoading } = api.customer.list.useQuery({ limit: 50 });

  if (isLoading) return <Skeleton />;
  return <Table rows={data} />;
}

// src/features/customers/new-customer-form.tsx
"use client";
import { api } from "@/lib/trpc-react";

export function NewCustomerForm() {
  const utils = api.useUtils();
  const create = api.customer.create.useMutation({
    onSuccess: () => utils.customer.list.invalidate(),
  });

  return (
    <form onSubmit={(e) => {
      e.preventDefault();
      create.mutate({ name: "...", email: "..." });
    }}>
      ...
    </form>
  );
}
```

## Naming conventions

- **Router** name: singular noun matching the module — `customerRouter`, `orderRouter`.
- **Procedure** name: verb describing intent — `list`, `getById`, `create`, `update`, `delete`, `award`, `markSent`. Avoid `get*` prefix; just say what it does.
- **Mounted as**: singular in `appRouter` — `customer: customerRouter`. Client calls become `api.customer.list.useQuery()`.

## When a procedure needs to compose

If `salesOrder.create` needs to look up customer info as part of its work, it does so through `customerService.findById`, **not** through tRPC. tRPC is the delivery layer; services compose in-process.

## Streaming / subscriptions

tRPC v11 supports subscriptions over WebSockets, but this stack avoids that (route handlers can't host WebSockets). For long-running responses, use:

- **Server-Sent Events** via a regular route handler (`src/app/api/.../stream/route.ts`), or
- **Polling** with React Query's `refetchInterval`, or
- **A dedicated worker** outside this Next.js process.

## Testing procedures

Use the server-side caller (no HTTP):

```ts
// src/server/api/routers/customer.spec.ts
import { appRouter } from "@/server/api/root";

const caller = appRouter.createCaller({
  db: testDb,
  session: { user: { id: "test-user", email: "t@example.com" } } as any,
});

it("lists customers", async () => {
  const rows = await caller.customer.list({ limit: 10 });
  expect(rows).toHaveLength(0);
});
```

Typed end-to-end, no HTTP overhead. See `testing-patterns/SKILL.md` for more.
