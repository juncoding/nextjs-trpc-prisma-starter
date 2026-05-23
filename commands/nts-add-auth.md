---
description: "Add Better Auth to an existing nextjs-trpc-prisma-starter project that skipped auth at scaffold time. Adds the Better Auth Prisma adapter, session + permission helpers, /login page, the auth route handler, the User/Session/Account/Verification + Role/Permission Prisma models, and the migration. Updates tRPC context to include session and switches existing routers from publicProcedure to protectedProcedure."
---

Invoke the `nextjs-trpc-prisma-starter:nts-add-auth` skill and follow it exactly. The user wants to wire authentication. Confirm the auth strategy (credentials only / magic-link / OAuth providers) and walk through every file change before writing — this is a substantial change that touches every existing tRPC router.
