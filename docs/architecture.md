# Architecture

This document explains the long-form rationale behind the stack, the structure, and the patterns the `nextjs-trpc-prisma-starter` plugin promotes. It mirrors the in-skill reference files so users skimming the repo can read it without installing the plugin.

## The shape of a project built with this plugin

A single Next.js application serves both the **SPA frontend** (client components + React Query via tRPC) and the **backend API** (tRPC procedures + route handlers). One process, one deploy, one type system, one dependency tree.

```
┌──────────────────────────────────────────────────────────┐
│           Browser — SPA built from client components     │
│                                                          │
│   const { data } = api.customer.list.useQuery({...})    │
│                              │                          │
└──────────────────────────────│──────────────────────────┘
                               │ tRPC over HTTP (batched)
                               ▼
┌──────────────────────────────────────────────────────────┐
│   src/app/api/trpc/[trpc]/route.ts  ← single entry      │
│                              │                          │
│                              ▼                          │
│   src/server/api/routers/customer.ts  ← thin pipe       │
│                              │                          │
│                              ▼                          │
│   src/server/modules/customer/customer.service.ts       │
│     - requirePermission(userId, "customers:read")       │
│     - validates input                                   │
│     - calls Prisma inside a transaction                 │
│     - logs to audit                                     │
│                              │                          │
│                              ▼                          │
│                          PostgreSQL                     │
└──────────────────────────────────────────────────────────┘
```

The same services are also called from:
- `src/app/api/mcp/route.ts` (MCP tools — for AI clients).
- `src/server/jobs/` (cron).
- Future `src/app/api/v1/*` route handlers (when a REST surface is genuinely needed).

In every case, the service is unchanged. Only the wrapper differs.

## Why this stack — short version

| Pick | Reason |
|---|---|
| Next.js (App Router, SPA mode) | One framework hosts both the SPA shell and route handlers. Battle-tested. |
| tRPC | Typed RPC over HTTP. Ships React Query. `createCaller` is the best test primitive in any framework. |
| Prisma | Mature ORM. Migrations + type generation + good CRUD DX. |
| Better Auth | Modern, RBAC built-in, MCP plugin available out of the box. |
| Zod | One schema, used server-side (tRPC `.input()`) and client-side (form validation). |
| Jest | Pragmatic. Works against services, tRPC `createCaller`, and route handlers. |

## Why this stack — long version

See [`docs/why-this-stack.md`](./why-this-stack.md) for the comparison vs. Server Components / Server Actions, vs. SPA + NestJS, vs. plain REST + React Query.

## Architectural invariants

1. **`src/app/` is a thin delivery layer.** No business logic, no DB queries. Pages, providers, route handlers — that's it.
2. **`src/server/` is the entire backend.** Every file starts with `import "server-only";` so the boundary is enforced at build time.
3. **Permissions live in services, not in the router.** Every service method touching user-owned data takes `userId` first and calls `requirePermission`.
4. **Audit calls live in services**, inside the same transaction as the mutation.
5. **Feature-first organization.** Group by business domain (`modules/customer/`), not by technical layer.
6. **tRPC routers are dumb pipes.** They validate input, pick public vs. protected, and call the service. No business logic.
7. **Route handlers are reserved for non-tRPC use cases**: MCP, webhooks, file uploads, third-party REST. Internal app data goes through tRPC.

## The four-step recipe for a new module

1. **Model.** Add the table(s) to `prisma/schema.prisma`. Migrate.
2. **Module.** Create `src/server/modules/<name>/` with `<name>.service.ts`, `<name>.schema.ts`, `<name>.types.ts`. Service takes `userId` first, calls `requirePermission`, audits.
3. **Router.** Create `src/server/api/routers/<name>.ts` with one procedure per service method. Mount in `src/server/api/root.ts`.
4. **UI.** Create `src/features/<name>/` with the table, form, detail components. Call `api.<name>.<procedure>.useQuery()` / `.useMutation()`. Wire to a route in `src/app/(dashboard)/<name>/`.

Every step has a worked example in the plugin's skills.

## What NOT to do

- Use Server Actions. This stack is SPA mode — use tRPC mutations.
- Put DB queries in pages or route handlers. They go in services.
- Add a permission check in the tRPC router. It goes in the service.
- Use `revalidateTag` / `revalidatePath`. React Query is the cache; invalidate via `utils.<query>.invalidate()`.
- Add WebSocket support inline. Next.js route handlers don't host upgrades — run a separate process or use a managed service.
- Skip the `import "server-only";` line in `src/server/` files. The boundary depends on it.

## Read more

- `skills/architecture-patterns/SKILL.md` — patterns reference, indexed by task.
- `skills/testing-patterns/SKILL.md` — how to test each layer.
- `skills/scaffold-internal-tool/references/folder-structure.md` — the full layout with inline comments.
