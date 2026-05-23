# tRPC procedure tests via createCaller

The whole reason this stack picked tRPC — `createCaller` lets you test procedures without HTTP, with full type inference.

## The basic pattern

```ts
// src/server/api/routers/customer.spec.ts
import { appRouter } from "@/server/api/root";
import { db } from "@/server/db/client";

jest.mock("@/server/db/client", () => ({
  db: { customer: { findMany: jest.fn() } },
}));

function makeCaller(session: { userId: string } | null = { userId: "test-user" }) {
  return appRouter.createCaller({
    db: db as any,
    session: session ? { user: { id: session.userId } } as any : null,
  });
}

describe("customer router", () => {
  it("list returns rows from the service", async () => {
    (db.customer.findMany as jest.Mock).mockResolvedValueOnce([{ id: "c-1", name: "Acme" }]);
    const caller = makeCaller();
    const result = await caller.customer.list({ limit: 10 });
    // ^^ TS knows result is { id: string; name: string; ... }[]
    expect(result).toEqual([{ id: "c-1", name: "Acme" }]);
  });

  it("list rejects when unauthenticated", async () => {
    const caller = makeCaller(null);
    await expect(caller.customer.list({ limit: 10 })).rejects.toMatchObject({
      code: "UNAUTHORIZED",
    });
  });

  it("list rejects bad input via Zod", async () => {
    const caller = makeCaller();
    // @ts-expect-error — limit must be a number
    await expect(caller.customer.list({ limit: "ten" })).rejects.toMatchObject({
      code: "BAD_REQUEST",
    });
  });
});
```

## What this gives you over REST + supertest

- **No HTTP boot.** Tests run in milliseconds, not hundreds of milliseconds.
- **Full TS types.** `caller.customer.list({ limit: 10 })` autocompletes; mistyping a procedure name is a compile error, not a runtime 404.
- **Same ctx as production.** You pass `{ db, session }` — the same shape `createTRPCContext` returns. If you change the context, your tests break at compile time.

## Building a reusable context factory

To stop repeating `appRouter.createCaller({...})` everywhere, extract:

```ts
// tests/helpers/trpc-caller.ts
import { appRouter } from "@/server/api/root";
import { db } from "@/server/db/client";

export function caller(opts?: { userId?: string | null; dbOverride?: typeof db }) {
  const userId = opts?.userId === null ? null : opts?.userId ?? "test-user";
  return appRouter.createCaller({
    db: opts?.dbOverride ?? db,
    session: userId ? ({ user: { id: userId } } as any) : null,
  });
}
```

Then tests read:

```ts
await caller().customer.list({ limit: 10 });
await caller({ userId: null }).customer.list({ limit: 10 });  // unauthed
```

## What to assert at the router layer

- The procedure is wired (calling it returns the expected shape).
- The right procedure variant is used (`protectedProcedure` vs `publicProcedure`).
- Input passes through to the service.

Do NOT re-test the service's business logic here. That's covered in `service.spec.ts`.

## Testing mutations + the React Query invalidation pattern

The router tests verify the mutation runs. The React Query invalidation on the client (`utils.customer.list.invalidate()`) is a UI concern — verified by component tests or Playwright, not here.

## When you want to test against a real Postgres

Wire the integration DB into the context:

```ts
import { PrismaClient } from "@prisma/client";

const testDb = new PrismaClient({
  datasourceUrl: process.env.TEST_DATABASE_URL,
});

const result = await caller({ dbOverride: testDb }).customer.list({ limit: 10 });
```

Now the procedure runs end-to-end: Zod validation → router → service → real Postgres. Use sparingly — these tests are slower.

## Anti-patterns

- **`caller()` with no session in protected-only tests** — verify it rejects, don't sneak around it.
- **Mocking the service when calling the router.** Defeats the purpose — you wanted the router to actually call the service. Mock Prisma instead.
- **Testing the same scenario at both service and router level.** Pick one. Service level wins for business logic; router level wins for delivery-layer concerns.
