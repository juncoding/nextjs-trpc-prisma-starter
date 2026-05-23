# nextjs-trpc-prisma-starter

A Claude Code plugin for scaffolding and maintaining lightweight internal management systems on **Next.js + tRPC + Prisma**, used in SPA / client-component mode.

Designed for solo developers and small teams building internal tools — admin dashboards, CRUD apps, back-office systems — where:

- The whole stack lives in **one Next.js project** (no separate API service).
- The UI is a **SPA** built from client components and React Query (via tRPC), not Server Components.
- The backend is a **real backend** (services, permissions, audit, transactions) reached through tRPC procedures and route handlers.
- An **MCP entry point** is wired in by default so AI clients can query the system over OAuth.
- Tests are **first-class**: services covered by Jest, procedures covered by tRPC's typed `createCaller`, browser flows by Playwright.

## What's in the box

| Component | Purpose |
|---|---|
| `/scaffold-tool` slash command | Kicks off the bootstrap Q&A — name, location, DB, auth, cache, MCP, deploy target. Generates the full project skeleton. |
| `/add-cache`, `/add-mcp`, `/add-auth` | Retrofit features into an existing scaffolded project. Updates `CLAUDE.md` as it goes. |
| `/review-project` | Audits the current project against the architectural invariants — flags missing `server-only`, DB calls in the delivery layer, sneaked-in Server Actions, mutations without permission or audit, router bloat, smuggled state libs. Categorizes findings by severity. |
| `scaffold-internal-tool` skill | The bootstrap engine. Triggers on intents like "start a new internal tool" / "scaffold an admin dashboard". |
| `architecture-patterns` skill | Reference patterns for ongoing development — service layer, tRPC procedures, permissions + audit, route handlers, error handling. |
| `testing-patterns` skill | How to test each layer cleanly. |
| `review-project` skill | Drift detector. Combines a fast `check-conventions.sh` script with Claude-judgment reads to catch architecture violations before they ship. |

## Installation

This is a [Claude Code plugin](https://docs.claude.com/en/docs/claude-code/plugins). Install via your project's `.claude/settings.json` or your user-level Claude Code config:

```json
{
  "plugins": {
    "nextjs-trpc-prisma-starter": {
      "source": "github:juncoding/nextjs-trpc-prisma-starter"
    }
  }
}
```

Or clone locally and reference by path:

```bash
git clone https://github.com/juncoding/nextjs-trpc-prisma-starter ~/Dev/nextjs-trpc-prisma-starter
```

Then in your `~/.claude/settings.json`:

```json
{
  "plugins": {
    "nextjs-trpc-prisma-starter": {
      "source": "/Users/you/Dev/nextjs-trpc-prisma-starter"
    }
  }
}
```

## Quick start

1. Open Claude Code in an empty directory (or one you want the project created next to).
2. Run `/scaffold-tool`.
3. Answer the Q&A: project name, location, database, auth, cache, MCP entry point, deployment target.
4. Claude scaffolds the project, writes `.env.example` and `CLAUDE.md`, and confirms with a verification run.

Later, retrofit features as needs evolve:

```
/add-cache       # Wire Redis + cache helpers
/add-mcp         # Add the MCP route handler + Better Auth mcp plugin
/add-auth        # Wire Better Auth if you skipped it initially
```

Each add-on updates `CLAUDE.md` so the project's documented architecture stays in sync with reality.

## Why this stack

See [`docs/why-this-stack.md`](docs/why-this-stack.md) for the long version. Short version: a single Next.js process hosts both the SPA frontend and the API, services live in `src/server/modules/` and are framework-agnostic (callable from tRPC, route handlers, MCP, cron — all unchanged), and tRPC's `createCaller` gives you the best testing story of any framework option for typed procedure tests.

This is NOT the right starter if you need:

- Server-rendered HTML for SEO (it's auth-walled SPA).
- WebSockets (Next.js route handlers don't support upgrade — use a separate process).
- A native iOS/Android client (tRPC is TypeScript-only without an adapter).

For everything else internal-tool-shaped, this is a strong, opinionated default.

## License

MIT — see [LICENSE](LICENSE).
