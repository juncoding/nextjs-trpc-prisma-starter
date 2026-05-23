---
name: nts-scaffold-internal-tool
description: "Scaffold a brand-new lightweight internal management system on Next.js + tRPC + Prisma in SPA / client-component mode. Use this whenever the user wants to start a new internal tool, admin dashboard, back-office app, CRUD app, management system, or operational SaaS starter — even if they don't name the stack. Walks the user through an interactive Q&A (project name, location, database, auth, cache, MCP, deployment target), then generates the canonical folder structure, dependencies, sample tRPC router, sample service, Prisma schema starter, .env.example, and CLAUDE.md."
---

# Scaffold a new internal management tool

This skill bootstraps a brand-new project on the **Next.js + tRPC + Prisma in SPA mode** stack. It is the entry point for the `nextjs-trpc-prisma-starter` plugin and is invoked either explicitly via `/nts-scaffold-tool` or when the user expresses intent to start a new internal management system.

## When to use this skill

Use this skill when the user is **starting a brand-new project** in one of these shapes:

- Internal admin dashboard / management system
- Back-office tool for staff
- Internal CRUD app
- Lightweight operational SaaS
- ERP-style line-of-business app
- Anything where the user says "scaffold / init / start / create a new <internal tool kind>"

Do NOT use this skill for:

- Adding a feature to an existing project (those have their own skills — `add-cache`, `add-mcp`, `add-auth`).
- Public-facing marketing sites, content sites, e-commerce storefronts (SEO matters, different stack tradeoffs).
- Mobile-first products (tRPC is TypeScript-only without an adapter).

## Why an interactive flow

The stack is opinionated but the project has variables (database, auth provider, whether to wire cache from day one, deploy target). Asking up front means the generated project is **complete and consistent** rather than half-configured. The user can always add things later via the `add-*` skills.

Use the `AskUserQuestion` tool for each step so the user gets a clean UI with options. Ask one question per `AskUserQuestion` call, not all at once — they shape later questions (e.g. answering "PostgreSQL" determines which Prisma adapter to install).

## Conversation flow

Walk the user through these questions in this order. Stop and confirm before any file write.

### 1. Project name

Open-ended. Validate: lowercase, hyphens-only, no spaces, valid as both a folder name and an npm package name.

### 2. Project location

Options:
- **New directory under current working directory** (e.g. `./<project-name>/`)
- **Use current working directory** (must be empty — check first with `ls -A`)
- **Custom absolute path**

If "current directory" is chosen, run `ls -A` and abort if anything other than `.git/` is present. Don't overwrite the user's stuff.

### 3. Database

Options:
- **PostgreSQL (recommended)** — production default. Uses `@prisma/adapter-pg` driver.
- **SQLite** — for prototyping / very small deployments. No driver adapter needed.
- **MySQL** — if the team has existing MySQL infrastructure.

Skip MongoDB — Prisma supports it but the patterns in `architecture-patterns` assume relational. Tell the user that if they ask.

### 4. Auth

Options:
- **Better Auth (recommended)** — modern, RBAC built-in, MCP plugin available, credentials + magic-link + OAuth providers.
- **NextAuth / Auth.js** — if the user has prior experience.
- **Skip for now** — generate without auth wiring; user can run `/nts-add-auth` later.

### 5. Cache

Options:
- **Skip (recommended for start)** — Next.js's default in-process cache is fine until measurably not.
- **Redis** — wire `ioredis` + a small cache helper from day one. Adds `docker-compose.yml` service.

### 6. MCP entry point

Options:
- **Yes (recommended)** — wires `/api/mcp/route.ts` with Better Auth's `mcp` plugin acting as OAuth provider. Adds one `rfq_search`-style example tool. Requires Better Auth (from step 4) — if user skipped auth, warn and offer to enable both.
- **Skip** — easy to add later via `/nts-add-mcp`.

### 7. Deployment target

Options:
- **Self-hosted Docker (e.g. on EC2)** — adds `Dockerfile`, `docker-compose.yml`, `next.config.ts` with `output: 'standalone'`.
- **Vercel** — adds `vercel.ts` config, no Dockerfile.
- **Both / undecided** — adds the Docker bits but doesn't strip Vercel compat.

### 8. Email / templates (optional)

Options:
- **Skip**
- **Resend + Handlebars** (mirrors the proven pattern from production ncy-erp)

### 9. Confirm

Show a summary of all choices and the file/folder list that will be generated. User confirms or backs up.

## Generated structure

Files generated are derived from the answers above plus the templates in `assets/`. The canonical layout is documented in `references/folder-structure.md` — read it before writing.

Top level:

```
<project-name>/
├── src/
│   ├── app/
│   │   ├── (auth)/login/page.tsx
│   │   ├── (dashboard)/
│   │   │   ├── layout.tsx
│   │   │   └── page.tsx              # placeholder home
│   │   ├── api/
│   │   │   ├── trpc/[trpc]/route.ts
│   │   │   ├── mcp/route.ts          # if MCP=yes
│   │   │   └── auth/[...all]/route.ts # if Better Auth
│   │   ├── layout.tsx
│   │   └── providers.tsx             # tRPC + React Query providers
│   ├── server/
│   │   ├── db/client.ts
│   │   ├── auth/
│   │   │   ├── index.ts
│   │   │   ├── session.ts
│   │   │   └── permissions.ts
│   │   ├── modules/
│   │   │   └── _example/             # sample service + schema + types
│   │   ├── api/                      # tRPC routers
│   │   │   ├── root.ts
│   │   │   ├── trpc.ts               # context + base procedures
│   │   │   └── routers/
│   │   │       └── _example.ts
│   │   ├── mcp/                      # if MCP=yes
│   │   │   ├── registry.ts
│   │   │   └── tools/_example.ts
│   │   └── lib/
│   │       ├── logger.ts
│   │       ├── errors.ts
│   │       └── cache.ts              # if cache=Redis
│   ├── features/                     # feature-specific client UI
│   ├── components/ui/                # shadcn primitives (added as needed)
│   ├── lib/
│   │   ├── trpc-react.ts             # client-side tRPC + RQ hooks
│   │   └── utils.ts
│   ├── hooks/
│   └── env.ts                        # @t3-oss/env-nextjs
├── prisma/
│   ├── schema.prisma
│   ├── migrations/
│   └── seed.ts
├── tests/
│   └── e2e/                          # Playwright if requested
├── public/
├── docs/
│   ├── handoff.md                    # session-handoff doc (start-here for Claude)
│   └── architecture.md               # link to plugin's docs/
├── .env.example
├── .gitignore
├── CLAUDE.md                         # generated, reflects choices
├── Dockerfile                        # if deploy=docker
├── docker-compose.yml                # postgres + (redis if cache)
├── next.config.ts
├── tsconfig.json
├── package.json
├── jest.config.js
└── README.md
```

## Generation steps in order

Execute these steps sequentially. After each step, briefly confirm completion before moving on.

1. **Create root + directory tree.** `mkdir -p` the full tree.
2. **Write `package.json`** using `assets/package.json.template`, filling in the dependencies based on choices.
3. **Write `tsconfig.json`, `next.config.ts`, `jest.config.js`** from templates.
4. **Write `prisma/schema.prisma`** using `assets/prisma-schema.starter.prisma`, swapping the datasource provider per the DB choice.
5. **Write `src/env.ts`** with `@t3-oss/env-nextjs` schema reflecting which env vars are required given the choices.
6. **Write `.env.example`** using `references/env-example-template.md` — only include keys that the project actually needs (e.g. omit `REDIS_URL` if cache=skip).
7. **Write the tRPC scaffolding** — `src/server/api/{trpc,root}.ts` plus a single `_example` router showing the protectedProcedure pattern.
8. **Write the service-layer scaffolding** — `src/server/modules/_example/` with a minimal service, schema, and types showing `userId`-first + permission check + audit pattern.
9. **Write the auth scaffolding** (if not skipped) — Better Auth config + session helper + permissions helper.
10. **Write the MCP route** (if requested) — `src/app/api/mcp/route.ts` + `src/server/mcp/registry.ts` + one example tool.
11. **Write the client providers** — `src/app/providers.tsx` wiring tRPC + React Query.
12. **Write `Dockerfile` + `docker-compose.yml`** if Docker deploy.
13. **Write `CLAUDE.md`** using `references/claude-md-template.md`, filled in with the choices. This is the contract for future Claude sessions on the project.
14. **Write `docs/handoff.md`** stub — empty section headers, ready to be filled in as the project grows. Modeled on the ncy-erp handoff style.
15. **Write `README.md`** for the project — short, repo-facing.
16. **`git init`** + first commit `chore: initial scaffold from nextjs-trpc-prisma-starter`.
17. **Verification step** — run `pnpm install`, `pnpm prisma generate`, `pnpm tsc --noEmit`. Report results. Do not try to run migrations (no DB yet); the user owns that.

## Key templates and references

The work is data-driven from the answers + these files:

- `references/stack-rationale.md` — explains why this stack (read if user asks "why not X").
- `references/folder-structure.md` — the canonical layout, expanded with comments.
- `references/claude-md-template.md` — the `CLAUDE.md` template with variable slots.
- `references/env-example-template.md` — the `.env.example` template, keyed by which optional features were enabled.
- `assets/*.template` — actual file bodies to drop in, with `{{VARIABLE}}` slots.

When writing a file, read the corresponding template, substitute variables, then write. Don't generate from scratch — the templates carry months of hard-won decisions.

## Post-scaffold

After the scaffold lands, point the user at the next moves:

- `pnpm dev` to start.
- Edit `prisma/schema.prisma` to add their first real model.
- `pnpm prisma migrate dev --name init` to apply.
- `/nts-add-cache`, `/nts-add-mcp`, `/nts-add-auth` to retrofit later.
- See `docs/architecture.md` in the project for ongoing patterns.

## Sanity guards

- **Never overwrite an existing file** without explicit confirmation. Always `ls` the target directory first.
- **Never run `pnpm install` in the user's current directory** if the project location is "new subdirectory" — `cd` into the new dir first.
- **Never push to a remote** automatically. The user owns that.
- **Never invent dependencies** — every dep in `package.json.template` exists and is on a real version.
- **Never skip the CLAUDE.md step** — it's the most load-bearing file in the project's future, since every future Claude session reads it first.
