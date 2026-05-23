---
name: nts-add-mcp
description: "Add an MCP (Model Context Protocol) entry point to an existing project scaffolded with nextjs-trpc-prisma-starter. Use this when the user wants AI clients (Claude Desktop, Cursor) to query the project's data over OAuth, mentions MCP, wants to expose tools to AI, or invokes /nts-add-mcp. Wires up /api/mcp/route.ts, the MCP plugin in Better Auth (the project's OAuth provider), the .well-known OAuth discovery endpoints, a tool registry at src/server/mcp/registry.ts, one example tool, and the migration for the three OAuth tables. Requires Better Auth to be wired — if not, prompts to run /nts-add-auth first."
---

# Add MCP entry point to an existing project

## Use when

- User wants Claude Desktop, Cursor, or any MCP-compatible AI client to interact with the app.
- User says "expose this to MCP" / "add MCP tools" / "let AI query the data".
- User invokes `/nts-add-mcp`.

## Prerequisite check

This skill requires **Better Auth** to be wired (the OAuth provider behind the MCP plugin). Before doing anything else:

1. Check for `src/server/auth/index.ts` — abort if missing.
2. Check that Better Auth is in `package.json` dependencies — abort if missing.

If auth isn't wired, tell the user to run `/nts-add-auth` first.

## What this skill does

1. Adds the `mcp` plugin to the Better Auth config.
2. Creates `src/app/api/mcp/route.ts` — the Streamable HTTP endpoint, wrapped in `withMcpAuth`.
3. Creates `src/app/.well-known/oauth-authorization-server/route.ts` and `src/app/.well-known/oauth-protected-resource/route.ts` for discovery.
4. Creates `src/server/mcp/registry.ts` — the tool dispatch table.
5. Creates `src/server/mcp/tools/_example-search.ts` — one worked tool wrapping a service.
6. Creates a Prisma migration to add the three OAuth tables (`oauth_application`, `oauth_access_token`, `oauth_consent`).
7. Updates `CLAUDE.md` to document the MCP entry point.
8. Adds dev tunnel instructions to the README (Claude Desktop only accepts HTTPS connectors).

## Confirmation flow

Before writing:

1. Verify project structure (Better Auth present, `src/app/api/` exists).
2. Pick the example tool — default is "search the first table the user has". If unclear, pick `example_search` against the `_example` module if it exists.
3. Show the file list. Confirm.

## File contents

### Update `src/server/auth/index.ts`

Find the `plugins: [...]` array and add `mcp({ loginPage: "/login" })`:

```ts
import { mcp } from "better-auth/plugins/mcp";

export const auth = betterAuth({
  // ... existing config
  plugins: [
    // ... existing plugins
    mcp({ loginPage: "/login" }),
  ],
});
```

### Create `src/app/api/mcp/route.ts`

Use the template at `assets/mcp-route.ts.template` from the scaffold-internal-tool skill (the content is portable — just substitute `{{IF_*}}` for the present case).

### Create `src/app/.well-known/oauth-authorization-server/route.ts`

```ts
import { auth } from "@/server/auth";

export async function GET() {
  return Response.json(await auth.api.getMcpOAuthMetadata());
}
```

(Better Auth's mcp plugin exposes this metadata helper — version may differ; check `better-auth/plugins/mcp` exports if the name changed.)

### Create `src/server/mcp/registry.ts` and `src/server/mcp/tools/_example-search.ts`

Use the templates `mcp-registry.ts.template` and `mcp-tool-example.ts.template` from the scaffold-internal-tool skill.

### Create migration

Run:

```bash
pnpm prisma migrate dev --name add_mcp_oauth_tables
```

Better Auth's CLI can generate the Prisma model declarations for the OAuth tables — see Better Auth docs for the current command (typically `npx @better-auth/cli generate`).

### Update `CLAUDE.md`

Add to the stack section:

```markdown
- **MCP:** Streamable HTTP at `/api/mcp`, Better Auth `mcp` plugin as OAuth provider. Tools in `src/server/mcp/tools/`.
```

Add to "Useful commands":

```markdown
- Local MCP testing: Claude Desktop only accepts HTTPS connectors. Tunnel via `cloudflared tunnel --url http://localhost:3000` and update `BETTER_AUTH_URL` + `next.config.ts` `allowedDevOrigins` to the tunnel host while testing.
```

## How to add more tools later

Tell the user (and put this in CLAUDE.md too):

> To add an MCP tool:
> 1. Create `src/server/mcp/tools/<tool-name>.ts` exporting `{ description, inputSchema, handler }`.
> 2. The handler should validate its input via the same Zod schema as the corresponding tRPC procedure, then call the service method with the OAuth-derived `userId`.
> 3. Register in `src/server/mcp/registry.ts`.
> 4. Restart `pnpm dev`. Test from Claude Desktop's MCP servers UI.

## Verification

```bash
pnpm install
pnpm prisma migrate dev
pnpm tsc --noEmit
pnpm build
```

Don't try to actually exercise the MCP flow from this session — that requires an MCP client. Tell the user how to test it manually.
