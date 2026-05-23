# Why this stack

Short version in [`README.md`](../README.md). Long version here — the trade-offs we considered and the reasoning that landed on Next.js + tRPC + Prisma in SPA / client-component mode.

## The constraints this stack is for

- **Internal management tool.** Auth-walled, no SEO, tens-to-low-hundreds of users, CRUD-heavy.
- **One framework.** Solo dev or small team. Can't afford a separate backend service.
- **SPA UX.** Snappy in-app navigation, React Query mental model for data.
- **A real backend.** Services, permissions, audit, transactions — not just thin endpoints.
- **AI-readable by default.** MCP entry point is expected.
- **First-class testing.**

If any of those don't fit your project, this stack might not either.

## Three alternatives we rejected and why

### vs. Server Components + Server Actions (Next.js's modern default)

Pros of Server Components:
- No API layer — page imports service directly.
- Faster initial paint (HTML arrives with data).
- Less code per feature.

Why we don't use them:
- **Hard to test endpoints in isolation.** Server Actions are opaque POSTs with obfuscated action IDs. No curl, no Postman, no contract tests at the HTTP layer.
- **No SPA-style ergonomics.** Optimistic updates are clunkier than React Query. No DevTools showing cache state.
- **Cache invalidation has a learning curve.** `revalidateTag` / `updateTag` / `cacheLife` interact in non-obvious ways.
- **Less familiar mental model.** Most working engineers know "frontend + backend"; Server Components blur that.

We pull SC patterns in selectively (e.g. for a rare page that genuinely benefits from server rendering), but they're not the default.

### vs. SPA (Vite) + NestJS API (two services)

Pros of two services:
- Familiar split. Frontend and backend visibly separate.
- Backend portable to other consumers (mobile, etc.).
- Decorator-based DI may feel structured.

Why we don't use it:
- **Two services to deploy, monitor, secure, version, and keep in sync** (OpenAPI + orval/codegen, or hand-written DTOs).
- **CORS, auth cookie sharing, two `tsconfig.json`s, two `package.json`s.**
- **No real benefit for an internal tool with a single consumer.** The API contract exists only to ferry data between halves of the same project.
- **NestJS opinions are heavyweight** for solo dev / small teams. The DI + decorators pay off at large team scale, not here.

If a real second consumer (mobile, partner API) ever materializes, this stack adds REST route handlers alongside tRPC without rewriting anything.

### vs. plain REST route handlers + React Query (no tRPC)

Pros of plain REST:
- curl/Postman friendly.
- Familiar to every backend dev.
- Easy to share with non-TS clients.

Why we use tRPC instead:
- **End-to-end types without codegen.** Server-side router type flows to the client; renaming a procedure is a compile error.
- **`createCaller` is the best procedure-test pattern** in any framework — typed, fast, no HTTP boot.
- **React Query hooks come for free.** `api.customer.list.useQuery()` — no fetch wrappers, no manual `queryKey` management for shared data.
- **For a single-TS-client internal tool, the lack of curl exploration is a small price** for the type safety and ergonomics.

If we needed to expose REST endpoints to a third party, we'd add them as route handlers next to the tRPC handler — same services, same auth. tRPC and REST coexist fine.

## What we're NOT optimizing for

- **SEO.** SPA shell, no SSR for crawlers. Internal tools don't need it.
- **Time-to-first-paint for un-cached page loads.** SSR would be faster here. SPA's first paint is the shell; data loads after. Acceptable trade for snappier in-app interaction.
- **Polyglot clients.** tRPC is TS-only without an adapter. If you have a Swift / Kotlin / Go client, add a REST layer alongside via `trpc-openapi` or hand-written route handlers.
- **WebSocket-driven realtime.** Next.js route handlers don't host upgrades. Use a separate process or managed service if needed.
- **Extreme scale.** This stack scales to hundreds of concurrent users on a small EC2 box. Tens of thousands need bigger thinking — Postgres tuning, CDN, possibly horizontal scaling, possibly extracting hot paths into separate services. Those are nice problems to have; deal with them when they arrive.

## What's identical across all the alternatives

The service layer pattern (`src/server/modules/<x>/<x>.service.ts`) is **the same regardless of which alternative you pick**. `userId`-first, `requirePermission` at the top, audit inside the transaction. That's the load-bearing decision. The delivery layer (Server Action vs tRPC vs REST vs MCP tool) is a wrapper around it.

If you build with this stack and later decide to switch the delivery layer, your services don't move. They're framework-agnostic by design.

## When to NOT use this stack

- **SEO-critical site** → SvelteKit, Next.js with Server Components, Astro.
- **Native mobile client first** → Build a REST or GraphQL backend so iOS/Android can consume it.
- **Heavy realtime** → Use a framework with first-class WebSockets (Phoenix, Hono on Node, custom Express server).
- **Static content** → Astro / Hugo / Eleventy.
- **You want to learn Server Components** → Use them. They're great, just different.

For everything internal-tool-shaped — admin dashboards, back-office apps, CRUD, lightweight SaaS — this is a strong, opinionated default.
