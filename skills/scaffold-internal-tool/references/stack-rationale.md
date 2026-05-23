# Why this stack

This document is the answer when the user asks "why not X?" during scaffolding. Read it before answering — it is opinionated and the opinions are load-bearing.

## The constraints this stack is shaped for

- **Internal management tool.** Auth-walled. No SEO requirement. Tens-to-low-hundreds of users. CRUD-heavy.
- **One framework to maintain.** Solo dev or small team. Cannot afford a separate backend service.
- **SPA UX preferred.** Snappy in-app navigation; React Query mental model for data.
- **Real backend.** Services, permissions, audit, transactions — not just thin endpoints.
- **AI-readable.** MCP entry point is expected by default.
- **Testable.** First-class story for unit, integration, and end-to-end tests.

## The picks

| Pick | Why this and not the alternatives |
|---|---|
| **Next.js (App Router)** | Single framework that hosts both the SPA shell and backend route handlers in one process. Battle-tested at every scale. Used here in SPA mode — client components + route handlers — *not* in Server Components mode. |
| **tRPC** | Typed RPC over HTTP. Ships React Query under the hood, so the client gets full caching/optimistic/devtools behavior. Procedure tests use `createCaller()` — the cleanest typed-test pattern in any Node framework. Beats REST + RQ + manually-shared types or codegen. |
| **Prisma** | Mature, opinionated ORM. Migrations, type generation, good DX for CRUD. Drizzle is a fine alternative if the team prefers closer-to-SQL. |
| **React Query (via tRPC)** | Standard SPA data layer. Cache, optimistic updates, retries, devtools. |
| **Better Auth** | Modern, RBAC built-in, MCP plugin available out of the box (turns the app into an OAuth provider so AI clients can authenticate). NextAuth/Auth.js works too — Better Auth is preferred for the MCP integration. |
| **Zod** | Validation at the boundary. Same schemas server-side (tRPC `.input(schema)`) and client-side (form validation). |
| **Jest** | Pragmatic test runner. Works against services, against tRPC `createCaller`, and against route handlers via supertest-style patterns. Vitest is a cosmetic alternative. |
| **`server-only` package** | Enforces the `src/server/` boundary at build time. A client component that imports a server module fails the build. |
| **PostgreSQL (default)** | Default for production. SQLite is fine for prototyping. MySQL works if the team has it. |

## What this stack deliberately rejects

- **Server Components + Server Actions as primary pattern.** Cleaner in some ways (no API layer) but ties the UI tightly to the rendering model, makes ad-hoc curl-style testing impossible, and the cache-invalidation story (`revalidateTag`, `updateTag`, `cacheLife`) has a real learning curve. We use route handlers instead so the boundary is visible and testable.
- **NestJS + Vite SPA (two services).** A whole second framework to deploy, configure, secure, and keep in sync via OpenAPI/orval. Not worth it for an internal tool — single Next.js process gives you all the same capability with less maintenance.
- **GraphQL.** Overhead unjustified at this scale. tRPC gives you typed contracts without the runtime weight or the schema language.
- **WebSockets in the same process.** Next.js route handlers don't support upgrade. If WebSockets become a requirement, run a small separate Node process or use a managed service (Ably, Pusher, Supabase Realtime).
- **Server-side state management libraries.** No Redux, no Zustand by default. tRPC + React Query covers server state; React's own `useState` + URL params cover local state. Add a state lib only when measurably needed.

## When to NOT use this stack

- **SEO-critical site.** This is SPA. Use SvelteKit, Next.js with Server Components, Astro, or similar.
- **Native mobile client required.** tRPC is TS-only without an adapter; you'd be back to REST or GraphQL.
- **WebSockets-heavy (chat, live cursors, kanban with realtime).** Out of scope for the same-process model.
- **Heavy compute workloads.** Next.js functions on Vercel have time limits; self-hosted is fine for moderate but not for hours-long jobs. Use a worker queue (BullMQ, Inngest) for those.

## What stays the same as a more SSR-flavored approach

- The `src/server/modules/` service layer pattern.
- Permission checks live in services (`userId` first), not at route boundaries.
- Audit calls inside the same transaction as the mutation.
- `server-only` enforces the boundary.
- Feature-first folder organization.

The change vs. an SSR app is purely the **delivery layer**: tRPC procedures + route handlers instead of Server Components + Server Actions. Services don't move.
