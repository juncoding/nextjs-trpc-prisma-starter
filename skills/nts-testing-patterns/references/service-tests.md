# Service-layer tests

The most important tests in the project. Write these for every service method that does anything beyond a trivial passthrough.

## Two flavors

### A. Unit test with mocked Prisma (fast, narrow)

Good for branch coverage — exercise every `if`, every state transition, every permission decision.

```ts
// src/server/modules/customer/customer.service.spec.ts
import { customerService } from "./customer.service";
import { db } from "@/server/db/client";
import { requirePermission } from "@/server/auth/permissions";
import { ForbiddenError } from "@/server/lib/errors";

jest.mock("@/server/db/client", () => ({
  db: {
    customer: { findMany: jest.fn(), create: jest.fn(), findUniqueOrThrow: jest.fn() },
    auditLog: { create: jest.fn() },
    $transaction: jest.fn(async (cb) => cb({
      customer: db.customer,
      auditLog: db.auditLog,
    } as any)),
  },
}));
jest.mock("@/server/auth/permissions", () => ({
  requirePermission: jest.fn(),
}));

describe("customerService.create", () => {
  beforeEach(() => jest.clearAllMocks());

  it("requires customers:write", async () => {
    (requirePermission as jest.Mock).mockRejectedValueOnce(new ForbiddenError("nope"));
    await expect(
      customerService.create("user-1", { name: "Acme", email: "a@b.com" })
    ).rejects.toThrow(ForbiddenError);
    expect(db.customer.create).not.toHaveBeenCalled();
  });

  it("creates + audits in one transaction", async () => {
    (db.customer.create as jest.Mock).mockResolvedValueOnce({ id: "c-1", name: "Acme" });
    const result = await customerService.create("user-1", { name: "Acme", email: "a@b.com" });
    expect(result).toEqual({ id: "c-1", name: "Acme" });
    expect(db.customer.create).toHaveBeenCalledWith({ data: { name: "Acme", email: "a@b.com" } });
    expect(db.auditLog.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ action: "customer.created", entityId: "c-1" }),
      })
    );
  });
});
```

### B. Integration test against a real DB (slower, deeper)

Good for "does this whole thing actually work with Postgres" smoke tests. One per module is usually enough.

The test runner doesn't manage the database — that's done outside of test code (typically via a `package.json` script that runs Prisma migrate against a separate `TEST_DATABASE_URL` before the suite starts):

```jsonc
// package.json
{
  "scripts": {
    "test:integration": "TEST_DATABASE_URL=postgresql://postgres:postgres@localhost:5432/test_db pnpm prisma migrate deploy && jest --config jest.integration.config.js"
  }
}
```

Inside the test, connect to that DB and reset state per test:

```ts
// src/server/modules/customer/customer.integration.spec.ts
import { PrismaClient } from "@prisma/client";
import { customerService } from "./customer.service";

const db = new PrismaClient({ datasourceUrl: process.env.TEST_DATABASE_URL });

beforeEach(async () => {
  await db.customer.deleteMany();
  await db.auditLog.deleteMany();
  await db.user.deleteMany();
});

afterAll(async () => {
  await db.$disconnect();
});

describe("customerService integration", () => {
  it("create → list → findById round trip", async () => {
    await db.user.create({
      data: { id: "test-user", email: "t@example.com", isSysadmin: true },
    });

    const created = await customerService.create("test-user", { name: "Acme", email: "a@b.com" });
    const listed = await customerService.list("test-user", { limit: 10 });
    const found = await customerService.findById("test-user", created.id);

    expect(listed).toHaveLength(1);
    expect(found?.name).toBe("Acme");
  });
});
```

Run against a dedicated test DB — `postgres-test` service in `docker-compose.yml`, or Testcontainers if the team prefers ephemeral instances.

## What to assert

For mutating methods:
- The Prisma call shape (`.create({ data: ... })`).
- The audit row shape.
- The return value structure.
- Permission denial path (throws, no DB calls).
- Validation denial path (bad input throws).

For read methods:
- Filter shape passed to Prisma.
- Sort order.
- Pagination boundaries.
- Permission denial.

For state-machine methods (`award`, `markSent`, `cancel`):
- Each legal transition succeeds.
- Each illegal transition throws `ConflictError`.
- Side effects (cascading creates, audit) happen atomically.

## Anti-patterns to avoid

- **Testing through the tRPC router when you mean to test the service.** Adds noise. Drop to the service directly.
- **Mocking too much.** If the test boils down to "the mocks return what I told them to," it's not testing real behavior. Use an integration test instead.
- **Testing Prisma itself.** `expect(db.customer.findMany).toHaveBeenCalled()` is fine, but going deeper into "the WHERE clause is exactly this" risks fragility. Prefer to test the *outcome* via an integration test.
- **Snapshot tests on DB rows.** They drift when fields are added. Assert specific keys you care about.
