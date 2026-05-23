---
name: nts-testing-patterns
description: "Test-writing patterns for projects scaffolded with nextjs-trpc-prisma-starter. Use whenever the user is writing or reviewing tests in such a project, asks 'how do I test X', wants to add test coverage for a new module, or needs to debug a failing test. Covers service-layer unit tests (the high-value layer), tRPC procedure tests via createCaller (typed, no HTTP), MCP tool tests, route handler tests, and Playwright e2e. Each section explains WHAT to test at that layer and HOW so test effort lands where it pays off."
---

# Testing patterns

## The testing pyramid for this stack

```
              ▲
             ▲▲▲              Playwright e2e (a few smoke flows)
           ▲▲▲▲▲▲▲           tRPC procedure tests via createCaller
         ▲▲▲▲▲▲▲▲▲▲▲        Service-layer tests ← MOST VALUE LIVES HERE
       ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲     Schema parsing tests (Zod, cheap, run lots)
```

The high-value layer is the **service**. Test it well. The other layers are thin enough that "did I wire it correctly" tests are cheap and sufficient.

## Index

| Testing this | Read this |
|---|---|
| A service method | `references/service-tests.md` |
| A tRPC procedure | `references/trpc-caller-tests.md` |
| An MCP tool | `references/service-tests.md` (same as a service — MCP tools are thin wrappers) |
| A route handler (REST, webhook) | `references/service-tests.md` + call the route fn directly |
| A full user flow | `references/e2e-playwright.md` |

## Where tests live

Colocate next to the code they test:

```
src/server/modules/customer/
├── customer.service.ts
├── customer.service.spec.ts        ← unit tests here
├── customer.schema.ts
└── customer.schema.spec.ts         ← Zod parsing tests

src/server/api/routers/
├── customer.ts
└── customer.spec.ts                ← createCaller tests

src/app/api/v1/orders/[id]/
├── route.ts
└── route.spec.ts                   ← route handler tests

tests/e2e/
└── customer-flow.spec.ts           ← Playwright
```

Tests next to code makes them findable when refactoring. The `jest.config.js` pattern `<rootDir>/src/**/*.spec.ts` picks them up.

## What to actually test

### Always test in services

- Permission denial — caller without scope throws.
- Input validation — bad input throws.
- The happy path — correct DB calls, correct return shape.
- Important branches — state-machine transitions, conditional cascades.
- Tx rollback — failing audit rolls back the mutation.

### Test sparingly in routers

- "Public procedure is public" / "protected procedure rejects unauthenticated" — one of each, for sanity.
- That input passes through unchanged.

Do NOT re-test the service from the router level. That's duplication. The router is a pipe; verifying the pipe doesn't kink is enough.

### Test minimally in MCP tools and route handlers

If the tool/handler is genuinely a thin wrapper around the service, one test that confirms it calls the service is enough. The service tests cover the rest.

### Test e2e for golden flows only

- Login → land on dashboard.
- Create a record via the UI, verify it appears in the list.
- One full per-domain happy path (e.g. quote → award → SO created).

Don't try to e2e-test every form validation. That's what the service + router tests are for.

## What NOT to mock

- **Prisma in service tests**: mocking the entire Prisma client is brittle and provides false confidence. Prefer either:
  - **Real DB via Testcontainers** (slower but real) for the canary integration test per module.
  - **A targeted mock** of `db.<table>.<method>` for branch-coverage unit tests.
- **`requireSession` / `requirePermission`**: mock with `jest.mock(...)` — they're auth boundary, not what you're testing.
- **External services** (Resend, S3, Gotenberg): always mock. Don't hit live services in tests.

## What's worth automating vs. manual

Automate:
- Anything tied to a permission grant (so a role-permission change can't silently break access).
- State-machine transitions.
- Currency/unit/timezone conversions.
- Anything that has bitten you once.

Manual:
- Visual layouts.
- New UI components on first review.
- Anything where the test-writing time exceeds the bug-finding return.

## Running tests

```bash
pnpm test                  # full suite, headless
pnpm test:watch            # watch mode for a focused module
pnpm test customer.service # filter
```

The full suite should stay green at every commit. If a test goes red, fix it or delete it — don't let red tests accumulate.
