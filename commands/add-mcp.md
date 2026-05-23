---
description: "Add an MCP (Model Context Protocol) entry point to an existing nextjs-trpc-prisma-starter project. Wires /api/mcp/route.ts, the Better Auth mcp plugin (OAuth provider), .well-known discovery endpoints, a tool registry, one example tool, and the OAuth tables migration. Requires Better Auth — runs /add-auth check first."
---

Invoke the `nextjs-trpc-prisma-starter:add-mcp` skill and follow it exactly. The user wants AI clients (Claude Desktop, Cursor) to be able to query their app over OAuth. Verify Better Auth is wired before doing anything — if not, point them at /add-auth.
