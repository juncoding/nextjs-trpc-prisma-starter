# CLAUDE.md template

This is the template the scaffolder uses to generate the project's `CLAUDE.md`. Substitute `{{VARIABLES}}` based on the user's Q&A answers. This file is the single most load-bearing document in the project — every future Claude session reads it first.

Keep it **short**. The instinct is to write a manual; resist. CLAUDE.md should fit on two screens. Detail belongs in `docs/`.

## Template

```markdown
# Project conventions

`{{PROJECT_NAME}}` is a {{INTERNAL_TOOL_DESCRIPTION}}. Built on the **Next.js + tRPC + Prisma in SPA mode** stack, scaffolded with [`nextjs-trpc-prisma-starter`](https://github.com/juncoding/nextjs-trpc-prisma-starter).

**Before doing anything, read `docs/handoff.md`.** It carries the cumulative project context — what's shipped, what's next, locked decisions, gotchas.

## Stack (locked — do not re-litigate)

- **Framework:** Next.js {{NEXT_VERSION}} App Router, used in SPA mode (client components + tRPC + React Query — not Server Components / Server Actions).
- **API:** tRPC procedures at `/api/trpc/[trpc]`. Procedures live in `src/server/api/routers/`.
- **Database:** {{DATABASE}} + Prisma {{PRISMA_VERSION}}.
{{#IF_AUTH}}- **Auth:** {{AUTH_PROVIDER}}.{{/IF_AUTH}}
{{#IF_CACHE}}- **Cache:** Redis via `ioredis`, helpers in `src/server/lib/cache.ts`.{{/IF_CACHE}}
{{#IF_MCP}}- **MCP:** Streamable HTTP at `/api/mcp`, Better Auth `mcp` plugin as OAuth provider. Tools in `src/server/mcp/tools/`.{{/IF_MCP}}
{{#IF_EMAIL}}- **Email:** Resend + Handlebars templates.{{/IF_EMAIL}}
- **Validation:** Zod throughout.
- **UI:** shadcn/ui + Tailwind v4 (added on demand).
- **Tests:** Jest. Service-layer tests + tRPC `createCaller` procedure tests + Playwright e2e (when added).
- **Deploy:** {{DEPLOY_TARGET}}.

## Architectural invariants (do not break)

1. **`src/app/` is a thin delivery layer.** Pages, route handlers, providers. No business logic, no DB queries.
2. **`src/server/` is the entire backend.** Every file starts with `import "server-only";`.
3. **Permissions live in services, not routers.** Every service method touching user-owned data takes `userId` first and calls `requirePermission`.
4. **Audit calls live in services**, inside the same transaction as the mutation (if audit is wired).
5. **Feature-first organization** — group by business domain in `src/server/modules/` and `src/features/`, not by technical layer.
6. **tRPC routers are dumb pipes.** `.input(schema).query/mutation(({ ctx, input }) => service.method(ctx.session.user.id, input))`. No business logic in the router.
7. **Route handlers (`src/app/api/*/route.ts`)** are reserved for non-tRPC use cases: MCP, webhooks, file uploads, third-party-callable REST. Internal app data goes through tRPC.

## Package manager

{{PACKAGE_MANAGER}}. Never npm if pnpm is the choice.

## Commit convention

`feat(<module>): summary`. Squash-merge to main.

## Verification gate

Before claiming work is done:

```bash
{{PM}} format:check
{{PM}} tsc --noEmit
{{PM}} lint
{{PM}} build
{{PM}} test
{{PM}} prisma migrate diff --exit-code
```

CI runs the same gate.

## Useful commands

- `{{PM}} dev` — local dev (Next.js + Turbopack).
- `{{PM}} prisma migrate dev --name <name>` — create + apply a migration.
- `{{PM}} prisma studio` — DB GUI.
{{#IF_MCP}}- `{{PM}} dev` then tunnel via `cloudflared` for local MCP testing (Claude Desktop needs HTTPS).{{/IF_MCP}}

## Adding things later

This project was scaffolded with the `nextjs-trpc-prisma-starter` plugin. Retrofit features via:

- `/add-cache` — wire Redis cache helpers + `docker-compose.yml` service.
- `/add-mcp` — wire MCP entry point + Better Auth `mcp` plugin.
- `/add-auth` — wire Better Auth (if skipped at scaffold).

Each updates this `CLAUDE.md` automatically.

## When in doubt

See `docs/architecture.md` for the full architectural rationale (a copy of the plugin's reference patterns).
```

## Substitution variables

When generating, substitute:

| Variable | Example value |
|---|---|
| `{{PROJECT_NAME}}` | `acme-internal-tool` |
| `{{INTERNAL_TOOL_DESCRIPTION}}` | "the internal back-office tool for ACME Co" (ask the user) |
| `{{NEXT_VERSION}}` | `16` |
| `{{PRISMA_VERSION}}` | `7` |
| `{{DATABASE}}` | `PostgreSQL` / `SQLite` / `MySQL` |
| `{{AUTH_PROVIDER}}` | `Better Auth (credentials)` |
| `{{DEPLOY_TARGET}}` | `Self-hosted Docker` / `Vercel` |
| `{{PACKAGE_MANAGER}}` / `{{PM}}` | `pnpm` |

The `{{#IF_X}}...{{/IF_X}}` blocks should be included only if the corresponding feature was selected. Otherwise drop the whole block.
