# Canonical folder structure

The structure the scaffolder generates. Every part exists for a reason — explained inline.

```
<project-name>/
├── src/
│   ├── app/                          # Next.js App Router — THIN delivery layer
│   │   ├── (auth)/                   # Route group: unauthenticated surface
│   │   │   └── login/page.tsx        # Client component, posts to Better Auth
│   │   ├── (dashboard)/              # Route group: authenticated app
│   │   │   ├── layout.tsx            # Sidebar + header + requireSession()
│   │   │   └── page.tsx              # Placeholder home — replace
│   │   ├── api/
│   │   │   ├── trpc/[trpc]/route.ts  # tRPC HTTP handler — ALL app data flows through here
│   │   │   ├── mcp/route.ts          # MCP Streamable HTTP endpoint (if enabled)
│   │   │   ├── auth/[...all]/route.ts # Better Auth handler (if Better Auth)
│   │   │   └── health/route.ts       # Liveness probe
│   │   ├── layout.tsx                # Root layout, mounts <Providers>
│   │   ├── providers.tsx             # tRPC + React Query + Theme providers
│   │   └── globals.css
│   │
│   ├── server/                       # ← THE BACKEND. Every file imports "server-only"
│   │   ├── db/
│   │   │   └── client.ts             # Prisma client singleton
│   │   ├── auth/
│   │   │   ├── index.ts              # Better Auth config
│   │   │   ├── session.ts            # requireSession() helper
│   │   │   └── permissions.ts        # requirePermission(userId, scope)
│   │   ├── modules/                  # Business domains — service / schema / types / (repo)
│   │   │   └── _example/             # Sample module — delete after first real one lands
│   │   │       ├── _example.service.ts
│   │   │       ├── _example.schema.ts
│   │   │       └── _example.types.ts
│   │   ├── api/                      # tRPC routers
│   │   │   ├── trpc.ts               # createTRPCContext, publicProcedure, protectedProcedure
│   │   │   ├── root.ts               # appRouter = createTRPCRouter({...})
│   │   │   └── routers/
│   │   │       └── _example.ts       # Sample router — calls _example.service
│   │   ├── mcp/                      # MCP tools (if MCP enabled)
│   │   │   ├── registry.ts           # Maps tool name → handler
│   │   │   └── tools/
│   │   │       └── _example.ts       # Sample tool — wraps a service method
│   │   ├── actions/                  # Reserved for occasional server actions (rare in SPA mode)
│   │   ├── jobs/                     # node-cron registrations (if cron added)
│   │   ├── email/                    # Resend client + templates (if email added)
│   │   ├── integrations/             # S3, Gotenberg, Stripe, etc. — one folder per external
│   │   └── lib/
│   │       ├── logger.ts             # Pino child loggers per module
│   │       ├── errors.ts             # ForbiddenError, NotFoundError, etc.
│   │       └── cache.ts              # Redis helpers (if Redis added)
│   │
│   ├── features/                     # Feature-specific UI (not routes)
│   │   └── _example/
│   │       ├── _example-table.tsx    # Calls api._example.list.useQuery
│   │       ├── _example-form.tsx     # Calls api._example.create.useMutation
│   │       └── _example-detail.tsx
│   │
│   ├── components/                   # Reusable UI primitives
│   │   ├── ui/                       # shadcn components (added on demand)
│   │   ├── forms/                    # Form-level reusables
│   │   └── layout/                   # Sidebar, header, etc.
│   │
│   ├── hooks/                        # Client-side React hooks
│   ├── lib/                          # Isomorphic utilities (safe on both sides)
│   │   ├── trpc-react.ts             # createTRPCReact<AppRouter>() — typed client hooks
│   │   └── utils.ts
│   ├── types/                        # Shared types (cross-module)
│   └── env.ts                        # @t3-oss/env-nextjs validated env
│
├── prisma/
│   ├── schema.prisma                 # Datasource + generators + models
│   ├── migrations/                   # `prisma migrate dev` output
│   └── seed.ts                       # `pnpm prisma db seed`
│
├── tests/
│   └── e2e/                          # Playwright (if requested)
│
├── public/                           # Static assets
├── docs/
│   ├── handoff.md                    # Session handoff doc — Claude reads this first each session
│   └── architecture.md               # Symlink or copy of plugin's architecture doc
│
├── .env.example                      # Checked in. Lists every required env key.
├── .env.local                        # Gitignored. Real values live here.
├── .gitignore
├── CLAUDE.md                         # The project's contract with Claude. Always read first.
├── Dockerfile                        # If Docker deploy
├── docker-compose.yml                # Postgres + (Redis if enabled)
├── next.config.ts                    # output: 'standalone' if Docker
├── tsconfig.json
├── jest.config.js
├── package.json
└── README.md
```

## Boundary rules (enforced)

- **`src/app/` files do NOT contain business logic.** They:
  - Validate input via Zod
  - Call a service or a tRPC procedure
  - Return the result

- **`src/server/` files MUST start with `import "server-only";`.** This makes the boundary visible and lets Next.js error if a client component pulls it in.

- **Permissions live in `src/server/modules/<x>/<x>.service.ts`, not in the tRPC router or route handler.** Every service method takes `userId` first and calls `requirePermission(userId, "scope")`. Routers and handlers are dumb pipes.

- **Audit calls live inside the service transaction.** So a failed audit fails the mutation atomically.

- **Cross-module composition is in-process.** `salesOrderService` imports `customerRepo` directly. No HTTP between modules.

## Feature-first, not layer-first

Group by business domain (`modules/customer/`, `modules/order/`), not by technical layer (`services/`, `repos/`, `schemas/` at top level). Easier to navigate, easier to extract into a separate package later if scaling demands it.

## Where the UI lives

- **`src/app/(dashboard)/<feature>/page.tsx`** — the route, very thin. Renders a client component from `src/features/`.
- **`src/features/<feature>/`** — the actual UI for the feature. Tables, forms, detail panels. Client components that call `api.<feature>.<procedure>.useQuery()` or `.useMutation()`.
- **`src/components/ui/`** — shadcn primitives only. Not feature-specific.

This split keeps routes navigable (`app/` mirrors the URL tree) and feature UI co-located (`features/<feature>/` has everything for that feature in one place).
