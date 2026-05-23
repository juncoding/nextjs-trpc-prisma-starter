---
name: review-project
description: "Review an existing project scaffolded with nextjs-trpc-prisma-starter against the architectural invariants and patterns. Use this whenever the user wants to audit project conventions, asks 'does this follow our patterns', wants a pre-PR architecture check, suspects drift, is onboarding a new contributor, or invokes /review-project. Runs a mechanical check script for fast objective violations (missing server-only, DB queries in src/app/, Server Actions present, wrong cache primitives), then samples files for judgment calls, then produces a categorized report grouped by severity (must fix / should fix / notes / passing)."
---

# Review project against architecture invariants

For projects scaffolded with `nextjs-trpc-prisma-starter`. Detects drift from the patterns established by the scaffolder and the `architecture-patterns` skill.

## Use this skill when

- User asks "does this project follow our conventions?"
- Before a PR review or merge.
- After a substantial feature lands, to catch newly-introduced drift.
- During onboarding — quick health check for an unfamiliar codebase.
- User invokes `/review-project`.
- User suspects something feels off architecturally.

Do NOT use this skill on:

- Projects NOT scaffolded with this plugin (the rules are tuned for the tRPC + SPA stack). If structure detection fails, refuse and explain.
- Projects in the middle of a partial migration — the noise drowns the signal.

## The flow

1. **Verify project structure.** Confirm we're in a project this skill knows how to review.
2. **Run `scripts/check-conventions.sh`.** Mechanical, deterministic checks that take ~1s.
3. **Parse the script's findings.** Group by check type.
4. **Sample-read flagged files.** For checks that need judgment (e.g. "is this `src/app/` page genuinely thin?"), read 5-10 of the flagged files and verify.
5. **Sample-read passing files too.** Spot-check 3-5 files that the script didn't flag, to catch issues the script can't see (silent permission bypasses, drift in module organization, smuggled state-management libs).
6. **Produce the report.** Markdown, grouped by severity.

## Step 1 — Verify project structure

Refuse if any of these are missing:

```
src/server/api/trpc.ts          # tRPC plumbing — proves this is the plugin's stack
src/server/modules/              # service layer
src/app/api/trpc/[trpc]/route.ts # tRPC HTTP entry
CLAUDE.md                        # the project's contract
```

If missing, output:

> This project doesn't match the layout `nextjs-trpc-prisma-starter` expects (`src/server/api/trpc.ts` and `src/app/api/trpc/[trpc]/route.ts` are required to confirm SPA + tRPC mode). I won't review it with these rules — they'd produce noise. If this project is on a different stack (Server Actions, NestJS, etc.), it needs a different review skill.

## Step 2 — Run the script

```bash
bash scripts/check-conventions.sh
```

The script outputs tagged lines like:

```
MISSING_SERVER_ONLY: src/server/modules/order/order.service.ts
DB_IN_APP: src/app/(dashboard)/orders/page.tsx:8
SERVER_ACTION: src/server/actions/legacy.ts:3
WRONG_CACHE_PRIMITIVE: src/server/modules/customer/customer.service.ts:42:revalidateTag
ROUTER_BLOAT: src/server/api/routers/order.ts:25 (procedure body has 12 lines)
ROUTER_HAS_DB: src/server/api/routers/order.ts:30
STATE_LIB: zustand
SERVICE_NO_PERMISSION: src/server/modules/order/order.service.ts:markPaid
MUTATION_NO_AUDIT: src/server/modules/order/order.service.ts:markPaid
NO_TRANSACTION: src/server/modules/order/order.service.ts:bulkCreate
```

Plus a `=== Summary ===` block with counts.

Parse the output by tag. Don't trust the tags blindly — verify each finding by reading the actual file (especially for the heuristic ones like `MUTATION_NO_AUDIT`, which is a regex-based guess).

## Step 3 — Sample-read flagged files

For each *unique* file the script flagged, read it and confirm the finding is real. Some checks (especially `MUTATION_NO_AUDIT` and `SERVICE_NO_PERMISSION`) use simple regex that can have false positives — e.g. a service method that's a pure read but follows a write-shaped name.

Use the `architecture-patterns` skill's `references/` to remind yourself of the canonical shape before judging.

## Step 4 — Sample-read passing files

The script can't catch:

- Silent permission bypasses (`// @ts-ignore` near a `requirePermission` call, or commented-out checks).
- Drift in module organization (a new "utils" folder at the top level instead of inside a module).
- Subtle Server Action smuggling (`"use server"` directive in a TSX file the script missed — rare but check).
- Domain errors being thrown as raw `Error` everywhere instead of `NotFoundError` etc.
- Tests that test mocks instead of real behavior.
- A new dependency in `package.json` that doesn't fit the stack.

Spot-read:
- 2–3 service files that the script said are clean.
- The most-recently-modified file (whatever it is — `ls -t src/` to find).
- `package.json` for added deps that hint at architectural drift.

## Step 5 — Produce the report

Use this exact format:

```markdown
# Project review: <project-name>

**Mode detected:** Next.js + tRPC + Prisma (SPA mode) ✓
**Files scanned:** N TS/TSX files across src/
**Date:** <YYYY-MM-DD>

## 🔴 Must fix (N)

Severity rule: missing security/correctness primitive that the rest of the codebase depends on.

### <Finding category>

- `<path>:<line>` — <one-line explanation>
- `<path>:<line>` — <one-line explanation>

## 🟡 Should fix (N)

Severity rule: pattern violation that doesn't break correctness today but will erode invariants if not addressed.

### <Finding category>

- `<path>:<line>` — <one-line explanation>

## 🟢 Notes (N)

Severity rule: a rule-break with a comment explaining intent. Documenting that it was caught and judged OK.

### <Finding category>

- `<path>:<line>` — <one-line explanation, including the user's justification>

## ✅ Passing

- N/N `src/server/` files have `import "server-only";`
- 0 Server Actions found
- 0 `revalidateTag` / `revalidatePath` calls (SPA mode preserved)
- All M tRPC procedures are ≤3 lines per body
- React Query is the only state-management library

## Recommendations

<If "must fix" > 0:> Tackle 🔴 first — those are real holes.
<If patterns are repeated:> Pattern X appears in N files; consider a codemod or a project-wide refactor PR.
<If everything passes:> Healthy. Re-run after the next major feature.
```

## Severity guide

See `references/severity-guide.md` for the full rubric. Quick reference:

- **🔴 Must fix** — missing `import "server-only";`, missing `requirePermission` on mutation, missing `auditLog` on mutation, DB call in `src/app/`, Server Action present.
- **🟡 Should fix** — tRPC router bloat, mutation outside transaction, raw `Error` instead of domain error, smuggled state-management lib, manual cache primitive (`revalidateTag` etc.) in SPA-mode project.
- **🟢 Notes** — rule break with adjacent justification comment, intentional exception documented in CLAUDE.md.

## What this skill explicitly does NOT do

- **Lint / format / typecheck.** That's `pnpm verify` (or whatever the project's gate is). This skill is about architecture, not syntax.
- **Test coverage.** Different concern — covered by `testing-patterns`.
- **Performance review.** N+1 queries, missing indexes — out of scope.
- **Security audit beyond the boundaries.** Doesn't check for SQL injection, XSS, CSRF. Trusts that the framework's defaults plus the boundary rules cover the basics.
- **Code review of business logic.** Doesn't comment on whether `award` should fire before `markSent` or whatever. Architecture only.

If the user wants any of those, point them at the right tool.
