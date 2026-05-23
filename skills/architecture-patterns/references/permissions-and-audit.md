# Permissions and audit

## Why both

- **Permissions** answer "is this user allowed to do this *now*?"
- **Audit** answers "who did what, when, and why?"

They sit next to each other in every service mutation. They're independent — a denied request never reaches audit; every allowed mutation generates an audit row.

## Permissions

### Where they live

`src/server/auth/permissions.ts`

```ts
import "server-only";
import { db } from "@/server/db/client";
import { ForbiddenError } from "@/server/lib/errors";

export type PermissionScope =
  | "customers:read" | "customers:write"
  | "orders:read"    | "orders:write"
  | "users:read"     | "users:write"
  | "audit:read";

export async function requirePermission(userId: string, scope: PermissionScope) {
  // sysadmin shortcut
  const user = await db.user.findUnique({ where: { id: userId }, select: { isSysadmin: true } });
  if (user?.isSysadmin) return;

  const allowed = await db.rolePermission.findFirst({
    where: {
      role: { users: { some: { userId } } },
      permission: { scope },
    },
    select: { id: true },
  });

  if (!allowed) throw new ForbiddenError(`Missing permission: ${scope}`);
}
```

### Where they're called

Inside the service method, FIRST. Never in the tRPC router or route handler.

```ts
async create(userId: string, input: CreateCustomer) {
  await requirePermission(userId, "customers:write");
  // ...
}
```

Reason: a tRPC procedure, an MCP tool, a cron job, and a test all hit the same service. The service is the only chokepoint that's guaranteed to be on the path.

### Naming scopes

`<resource>:<action>` — `customers:read`, `customers:write`. Two actions per resource is usually enough; split into more (`customers:delete`, `customers:export`) only when there's a real role that needs the finer grain.

### Seeding roles

Roles + permissions are seeded via `prisma/seed.ts`. Common starting set:

- **admin** — every permission.
- **sales** — `customers:read|write`, `orders:read|write`, `audit:read`.
- **ops** — `orders:read|write`, `shipments:read|write`.
- **viewer** — every `*:read`.

Sysadmin is a boolean on `User.isSysadmin`, not a role — it short-circuits the permission check. Only the bootstrap admin should be sysadmin.

## Audit

### Where it lives

`src/server/modules/audit/audit.service.ts`

```ts
import "server-only";
import type { Prisma } from "@prisma/client";

interface AuditEntry {
  userId: string;
  action: string;                     // "customer.created", "order.shipped", etc.
  entityType?: string;                // "customer", "order"
  entityId?: string;
  parentEntityType?: string;          // for sub-entity rollups (e.g. RfqItem → Rfq)
  parentEntityId?: string;
  diff?: { before: unknown; after: unknown };
  metadata?: Record<string, unknown>;
}

export async function auditLog(tx: Prisma.TransactionClient, entry: AuditEntry) {
  await tx.auditLog.create({
    data: {
      userId: entry.userId,
      action: entry.action,
      entityType: entry.entityType,
      entityId: entry.entityId,
      parentEntityType: entry.parentEntityType,
      parentEntityId: entry.parentEntityId,
      diff: entry.diff ? (entry.diff as Prisma.InputJsonValue) : undefined,
      metadata: entry.metadata as Prisma.InputJsonValue | undefined,
      createdAt: new Date(),
    },
  });
}
```

### The `parentEntityType` pattern

When a sub-entity is mutated (e.g. `RfqItem` belongs to `Rfq`), set:

```ts
await auditLog(tx, {
  userId,
  action: "rfq.item.updated",
  entityType: "rfq_item",
  entityId: item.id,
  parentEntityType: "rfq",
  parentEntityId: item.rfqId,
});
```

Then the "Activity" tab on `/rfqs/[id]` can `OR`-union:

```ts
where: {
  OR: [
    { entityType: "rfq", entityId: rfqId },
    { parentEntityType: "rfq", parentEntityId: rfqId },
  ],
}
```

— and show everything that happened to the RFQ or any of its sub-entities, in one timeline.

### The `diff` field

Capture before/after snapshots for updates. Helper:

```ts
function diffSnapshots<T extends Record<string, unknown>>(before: T, after: T) {
  const changes: Record<string, { from: unknown; to: unknown }> = {};
  for (const key of Object.keys(after)) {
    if (before[key] !== after[key]) {
      changes[key] = { from: before[key], to: after[key] };
    }
  }
  return changes;
}
```

Store the full snapshots in `diff`, not just the changes — disk is cheap, and someone investigating a bug six months later will want both.

### Inside the same transaction

```ts
return db.$transaction(async (tx) => {
  const customer = await tx.customer.create({ data });
  await auditLog(tx, { userId, action: "customer.created", entityType: "customer", entityId: customer.id });
  return customer;
});
```

If the audit insert fails, the mutation rolls back. If the mutation rolls back, the audit row is never written. Atomicity.

## The combined call site

```ts
async create(userId: string, input: CreateCustomer) {
  await requirePermission(userId, "customers:write");   // 1. permission
  const data = CreateCustomerSchema.parse(input);       // 2. validate
  return db.$transaction(async (tx) => {                // 3. transaction
    const customer = await tx.customer.create({ data });
    await auditLog(tx, {                                // 4. audit
      userId,
      action: "customer.created",
      entityType: "customer",
      entityId: customer.id,
    });
    return customer;
  });
}
```

Four lines around the core write. This pattern repeats across every mutating service method. Copy it.
