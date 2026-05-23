# Service layer pattern

## Where it lives

`src/server/modules/<module>/<module>.service.ts`

One folder per business domain. The folder typically contains:

```
src/server/modules/customer/
├── customer.service.ts    # Public API of the module
├── customer.schema.ts     # Zod schemas + inferred types
├── customer.types.ts      # Internal types (joins, view shapes)
└── customer.repo.ts       # OPTIONAL — extract only when service.ts gets crowded
```

Simple modules inline Prisma calls in the service; heavy modules pull DB access into a repo file.

## The canonical shape

```ts
// src/server/modules/customer/customer.service.ts
import "server-only";
import { db } from "@/server/db/client";
import { requirePermission } from "@/server/auth/permissions";
import { auditLog } from "@/server/modules/audit/audit.service";
import {
  CreateCustomerSchema,
  UpdateCustomerSchema,
  ListCustomersSchema,
  type CreateCustomer,
  type UpdateCustomer,
  type ListCustomers,
} from "./customer.schema";

export const customerService = {
  async list(userId: string, input: ListCustomers) {
    await requirePermission(userId, "customers:read");
    const filters = ListCustomersSchema.parse(input);
    return db.customer.findMany({
      where: filters.q ? { name: { contains: filters.q, mode: "insensitive" } } : undefined,
      take: filters.limit,
      orderBy: { createdAt: "desc" },
    });
  },

  async findById(userId: string, id: string) {
    await requirePermission(userId, "customers:read");
    return db.customer.findUnique({ where: { id } });
  },

  async create(userId: string, input: CreateCustomer) {
    await requirePermission(userId, "customers:write");
    const data = CreateCustomerSchema.parse(input);
    return db.$transaction(async (tx) => {
      const customer = await tx.customer.create({ data });
      await auditLog(tx, { userId, action: "customer.created", entityId: customer.id });
      return customer;
    });
  },

  async update(userId: string, id: string, input: UpdateCustomer) {
    await requirePermission(userId, "customers:write");
    const data = UpdateCustomerSchema.parse(input);
    return db.$transaction(async (tx) => {
      const before = await tx.customer.findUniqueOrThrow({ where: { id } });
      const after = await tx.customer.update({ where: { id }, data });
      await auditLog(tx, {
        userId,
        action: "customer.updated",
        entityId: id,
        diff: { before, after },
      });
      return after;
    });
  },
};
```

## Rules, with reasons

### 1. First argument is always `userId`

So the permission check is impossible to forget. If a caller doesn't have a `userId` (cron, MCP without OAuth, system tasks), it has to make a deliberate choice — pass a `SYSTEM_USER_ID` sentinel, or pass null and have the service know to skip the check.

### 2. Validate inputs at the service boundary, not before

Even though tRPC `.input(schema)` already validates, the service re-parses. Reason: services are called from non-tRPC paths too (MCP, cron, tests). Validating in the service is the only way to guarantee the contract.

### 3. Mutations run inside `db.$transaction`

So a failed audit, a failed downstream check, or a constraint violation rolls back atomically.

### 4. Audit calls go inside the same transaction

If the audit insert fails, the mutation should fail. If the mutation rolls back, the audit row should too. The audit row is the receipt — if you can't write the receipt, the transaction didn't happen.

### 5. Cross-module composition is in-process

`salesOrderService` imports `customerService` directly. No HTTP between modules. They're all in the same Node process — making them talk over HTTP would be silly.

### 6. The service returns rich, typed data

Not transport-shaped JSON. Return the Prisma model (with whatever `include`s you need). The delivery layer (tRPC, MCP) handles serialization.

### 7. No `console.log` — use the per-module logger

```ts
import { logger } from "@/server/lib/logger";
const log = logger.child({ module: "customer" });

log.info({ userId, customerId }, "customer created");
```

Pino with structured fields. Future you (or `pino-pretty` in dev) thanks you.

## Repo extraction — when to split

Pull `customer.repo.ts` out when:

- Service file exceeds ~300 lines.
- A non-trivial query is reused by 2+ service methods.
- You start writing the same `include: { ... }` clause repeatedly — extract a `findByIdWithRelations` repo method.

Don't extract preemptively. A 50-line service with inline Prisma is fine.

## When you need read-only data from another service

```ts
// Inside salesOrderService:
const customer = await customerService.findById(userId, input.customerId);
```

The `userId` flows through. The permission check fires. If the calling user doesn't have `customers:read`, the inner call throws — the outer mutation never runs.

If you need to bypass permission for a system path (cron pulling all customers for a daily report), add an explicit `customerService.findByIdInternal()` method (no `requirePermission`) and name it loudly. Don't sneak around the check.

## Testing the service

```ts
// src/server/modules/customer/customer.service.spec.ts
import { customerService } from "./customer.service";
import { db } from "@/server/db/client";

jest.mock("@/server/db/client", () => ({
  db: {
    customer: {
      findMany: jest.fn(),
      create: jest.fn(),
    },
    $transaction: jest.fn((cb) => cb({ customer: db.customer })),
  },
}));

jest.mock("@/server/auth/permissions", () => ({
  requirePermission: jest.fn().mockResolvedValue(undefined),
}));

describe("customerService.list", () => {
  it("filters by q", async () => {
    (db.customer.findMany as jest.Mock).mockResolvedValue([]);
    await customerService.list("user-1", { q: "acme", limit: 20 });
    expect(db.customer.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { name: { contains: "acme", mode: "insensitive" } },
        take: 20,
      })
    );
  });
});
```

For integration tests against a real DB, see `testing-patterns/SKILL.md`.
