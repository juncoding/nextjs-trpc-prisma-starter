# Severity guide for review findings

How to categorize each finding the script (or your read) surfaces.

## 🔴 Must fix

The finding represents a **broken invariant** that other parts of the codebase depend on. If left unfixed, future code will assume the invariant holds and silently rely on a guarantee that isn't there.

| Finding | Why it's red |
|---|---|
| `src/server/` file without `import "server-only";` | The boundary is enforced at build time by this import. Without it, a client component could pull the file in, leak secrets, or run server-only code in the browser. |
| Service mutation without `requirePermission` | Permission is the security floor. Every caller (tRPC, MCP, cron, future REST) trusts the service. Skipping this means *every* delivery layer is silently insecure for this method. |
| Service mutation without `auditLog` | Audit is the receipt. Lost audit = ungovernable system. Compliance / debugging / "who did what" all break. |
| DB call inside `src/app/` (page, layout, route handler, action, middleware) | Bypasses the service, bypasses permissions, bypasses audit. The most common silent security hole. |
| `"use server"` directive present | This stack is SPA mode. Server Actions break the consistency of "all reads via tRPC procedures." A single smuggled action leads to a slippery slope. |
| `requirePermission` commented out, or `// @ts-ignore` adjacent to it | Someone disabled a check. Always investigate. |
| Hardcoded secret in source (Prisma URL with password, API key) | Standard security. |

## 🟡 Should fix

The finding is a **pattern violation** that doesn't break correctness today but is the start of drift. Left alone, it normalizes for future contributors who'll cite "well, there's already one over there."

| Finding | Why it's yellow |
|---|---|
| tRPC router procedure body > 3 lines | The router is supposed to be a dumb pipe. Logic creeping in means the service didn't fully encapsulate the operation. Refactor the logic into the service. |
| Service mutation outside `db.$transaction` | Means a failed audit (or a follow-up write) could leave half-committed state. Single-statement mutations are OK; anything compound should be in a tx. |
| Raw `throw new Error(...)` in a service | The domain error hierarchy (`NotFoundError`, `ConflictError`, etc.) exists so the delivery layer can map to HTTP / tRPC codes consistently. Raw `Error` defaults to 500. |
| `revalidateTag` / `revalidatePath` / `updateTag` / `cacheTag` / `cacheLife` in source | These belong to the Server Component cache model. In SPA mode, cache invalidation happens client-side via React Query (`utils.x.y.invalidate()`). Smuggled cache primitives won't work as expected. |
| State-management library that isn't React Query (redux, zustand, jotai, valtio, recoil, mobx) | tRPC + RQ covers server state; `useState` + URL covers local. Pulling in another state lib usually means someone misunderstood the model. Verify the *need* before approving. |
| `console.log` instead of `logger.info` in services | Pino is the project's logger; raw `console.log` defeats structured logging and won't have child-logger context. Easy to fix. |
| Module folder missing `*.schema.ts` for a module that takes input | Means input validation is happening somewhere else (probably in the router with an inline schema). Pull it into the module. |
| `any` or `as any` cast in a service signature | Hides intent. Either type it correctly or use `unknown` + a Zod parse. |

## 🟢 Notes

The finding is a **deliberate exception** — a rule break with adjacent justification that explains why it's the right call here. Worth noting in the report so future readers know it was reviewed and accepted, but no action needed.

| Finding | Why it's green |
|---|---|
| `requirePermission` missing on a method whose comment explicitly says "system-internal, no caller is a real user" | Intentional bypass for a system path. Confirm the comment is honest. |
| Mutation outside a transaction on a service with a comment explaining "single-statement upsert, idempotent" | Single-statement DB calls are atomic by Postgres semantics; a wrapping tx adds nothing. |
| `"use server"` directive with comment "// allowed: webhook handler that needs FormData parsing not available in route handlers" | Rare but legitimate. Document why. |
| A `src/server/` file without `server-only` that's named `*.types.ts` or `*.schema.ts` | If the file is pure types / Zod schemas (no runtime imports of `db`, `process.env`, etc.), `server-only` is unnecessary noise. Confirm by reading. |
| A page in `src/app/` that calls a service directly (not via tRPC) | This is the exception we leave open in the patterns doc — rare, must be commented with WHY. |

## How to write each finding

- Lead with the **file path and line number** so the user can jump straight to it.
- Follow with **one sentence** explaining what the rule is and how this violates it.
- Don't repeat the rule text verbatim across findings — the section header carries it.

Example:

> ### Missing `requirePermission` call
> - `src/server/modules/order/order.service.ts:25` — `markPaid` mutates `order.paidAt` but doesn't call `requirePermission`. Add `await requirePermission(userId, "orders:write")` at the top.

Concise, actionable, points at the fix.

## When in doubt

If a finding could plausibly be 🔴 or 🟡, default to 🔴. The cost of being wrong on a real security issue is high; the cost of over-flagging a style issue is low. The user can downgrade in their fix PR.
