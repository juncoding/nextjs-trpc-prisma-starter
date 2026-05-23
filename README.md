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

Two install paths — pick what fits.

| Path | What gets installed | Best for |
|---|---|---|
| **A. `npx skills` CLI** ([vercel-labs/skills](https://github.com/vercel-labs/skills)) | Skills only (SKILL.md files + references/scripts/assets) | Fastest install, cross-agent (Claude Code, Cursor, Codex, OpenCode, …) |
| **B. Claude Code plugin** (`/plugin` or `settings.json`) | Skills **+** slash commands **+** plugin manifest | Full experience inside Claude Code, including the `/scaffold-tool` etc. commands |

The skills work the same way under both paths (they trigger on user intent). Path B additionally gives you the explicit slash commands.

### Path A — `npx skills add` (recommended for quick install)

```bash
# Install everything to ~/.claude/skills/ for Claude Code, globally
npx skills add juncoding/nextjs-trpc-prisma-starter -g -a claude-code

# Browse what's in the repo without installing
npx skills add juncoding/nextjs-trpc-prisma-starter --list

# Install just one specific skill
npx skills add juncoding/nextjs-trpc-prisma-starter --skill architecture-patterns -g -a claude-code
```

Caveat: the `skills` CLI installs **skills** but not slash commands or the plugin manifest. The skills still trigger on intent (e.g. "scaffold a new internal tool" → `scaffold-internal-tool` skill fires), but you won't be able to type `/scaffold-tool` to invoke explicitly. If you want the slash commands, use Path B instead (or in addition).

### Path B — install as a full Claude Code plugin

Inside Claude Code, run `/plugin` and add this source:

```
github:juncoding/nextjs-trpc-prisma-starter
```

Or edit `~/.claude/settings.json` (user-level) / `.claude/settings.json` (project-level) directly:

```json
{
  "plugins": {
    "nextjs-trpc-prisma-starter": {
      "source": "github:juncoding/nextjs-trpc-prisma-starter"
    }
  }
}
```

Restart Claude Code. All 7 skills + 5 slash commands become available.

### Path C — clone locally (for iterating on the plugin itself)

```bash
git clone git@github.com:juncoding/nextjs-trpc-prisma-starter.git ~/Dev/nextjs-trpc-prisma-starter
```

Then point `source` at the local path:

```json
{
  "plugins": {
    "nextjs-trpc-prisma-starter": {
      "source": "/Users/you/Dev/nextjs-trpc-prisma-starter"
    }
  }
}
```

Local installs pick up edits immediately on Claude Code restart — useful when authoring the plugin.

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
