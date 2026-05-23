---
description: "Review the current project against the nextjs-trpc-prisma-starter architectural invariants. Runs a mechanical check script (server-only boundary, DB calls in src/app/, Server Actions, wrong cache primitives, router bloat, missing permissions/audit, smuggled state libs), then samples flagged files for judgment, then produces a categorized report (must fix / should fix / notes / passing)."
---

Invoke the `nextjs-trpc-prisma-starter:review-project` skill and follow it exactly. The user wants an architecture audit of their current project. Run the mechanical script first, then read the flagged files to verify findings, then produce the categorized report. Refuse cleanly if the project structure doesn't match this plugin's expected layout — don't try to apply tRPC + SPA rules to a project on a different stack.
