---
name: nts-architecture-patterns
description: "Reference patterns for ongoing development on a Next.js + tRPC + Prisma project scaffolded with nextjs-trpc-prisma-starter. Use this whenever adding a new module, writing a new tRPC procedure, deciding between tRPC vs route handler vs MCP tool, wiring permissions, structuring services, handling errors, or making any architectural decision in a project that was bootstrapped with this plugin. Triggers on phrases like 'add a new module', 'create a tRPC procedure', 'where should this logic go', 'follow project conventions', or any 'how do I do X in this project' question."
---

# Architecture patterns for ongoing development

For projects already scaffolded with `nextjs-trpc-prisma-starter`. Explains the patterns to follow when adding features. Companion to the `nts-scaffold-internal-tool` skill which only handles initial setup.

## Use this skill when

- Adding a new business module (e.g. `customer`, `order`, `invoice`).
- Adding a new tRPC procedure or route handler.
- Deciding whether something belongs in tRPC, a route handler, a MCP tool, or a cron job.
- Wiring permissions on a new resource.
- Structuring a service that touches multiple modules.
- Handling errors at any layer.
- Reviewing whether a PR follows project conventions.

## The four-rule cheat sheet

1. **`src/app/` is a thin delivery layer.** No business logic. No DB queries. Just: validate, call a service, return.
2. **`src/server/` is the entire backend.** Every file starts with `import "server-only";`.
3. **Permissions live in services.** Every service method touching user-owned data takes `userId` first and calls `requirePermission`.
4. **Audit calls live in services**, inside the same transaction as the mutation.

If you remember nothing else, remember these four.

## Reference index

Read the file matching your task:

| Doing this... | Read this |
|---|---|
| Creating a new business module (service, schema, types) | `references/service-layer.md` |
| Writing a tRPC procedure | `references/trpc-procedures.md` |
| Wiring auth / RBAC for a new resource | `references/permissions-and-audit.md` |
| Adding a REST endpoint (webhook, third-party callable, file download) | `references/route-handlers-for-rest.md` |
| Throwing / catching errors at any layer | `references/error-handling.md` |

## The delivery-layer matrix

When you have new functionality, decide which delivery layer it lives in:

| Caller | Delivery layer |
|---|---|
| The app's own UI | **tRPC procedure** in `src/server/api/routers/<module>.ts` |
| An AI client (Claude Desktop, Cursor) | **MCP tool** in `src/server/mcp/tools/` (wraps the same service) |
| A webhook (Stripe, Resend, Svix-signed) | **Route handler** at `src/app/api/webhooks/<provider>/route.ts` |
| A scheduled job | **Cron handler** in `src/server/jobs/` |
| A third-party that needs REST | **Route handler** at `src/app/api/v1/<resource>/route.ts` |
| File upload / download | **Route handler** (Web Streams API) |
| A test | **`createCaller`** for tRPC procedures, **direct service call** for service-layer tests |

All of these end up calling the **same service method** — only the wrapper layer differs.

## Anti-patterns to refuse

- **DB queries in client components.** Even via Server Components — this project is SPA mode. Data fetches go through tRPC.
- **DB queries in route handlers / tRPC procedures.** Those are delivery wrappers. The service owns Prisma.
- **Permission checks in route handlers or routers.** Easy to forget; goes in the service.
- **Business logic in `src/app/`.** If a route handler is more than ~10 lines of glue, the logic belongs in a service.
- **Server Actions.** This project doesn't use them. Use tRPC mutations instead. If you find one, refactor it.
- **`revalidatePath` / `revalidateTag` calls.** SPA mode — React Query is the cache. After a mutation, the client invalidates the relevant queryKey via `utils.invalidate()`.
- **Bypassing tRPC for "performance"** before measuring. tRPC batches calls and has minimal overhead. Optimize only when a real bottleneck appears.

## When to break the rules

The rules above exist because they pay rent — they make the codebase navigable, secure, and refactorable. Breaking them is allowed when the break itself is the cheaper option, and you're explicit about it.

Examples of legit breaks:

- A service method that reads but doesn't mutate **and** is called only from a public, unauthenticated route handler — the `userId`-first signature is awkward. Use `Anonymous` as a sentinel or accept `null`.
- A read that's hit hundreds of times per page and trivially memoizable — pull it out of tRPC and into a Server Component on a per-page basis. Document why.
- A `tsx` component that needs to call a service directly during initial render (rare in SPA mode but possible) — fine, but pull the same service into a tRPC procedure for the rest of the app.

When you break a rule, **leave a one-line comment** explaining why. Future you, or the next Claude session, needs to know it was intentional.
