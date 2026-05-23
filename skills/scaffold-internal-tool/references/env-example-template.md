# .env.example template

The scaffolder generates `.env.example` keyed by which optional features the user enabled. Only include keys the project actually needs — empty cruft trains the user to ignore the file.

## Always included

```bash
# Node environment — set automatically by Next.js, never override in dev/prod
# NODE_ENV=development

# Public URL of this app
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

## If database is PostgreSQL

```bash
# Postgres connection string. Prisma 7 uses driver adapters — URL must include user/password/host/db.
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/{{PROJECT_NAME}}
```

## If database is SQLite

```bash
# SQLite file path, relative to project root.
DATABASE_URL=file:./prisma/dev.db
```

## If database is MySQL

```bash
DATABASE_URL=mysql://root:root@localhost:3306/{{PROJECT_NAME}}
```

## If Better Auth

```bash
# Better Auth — a 32+ byte random secret. Generate with: openssl rand -base64 32
BETTER_AUTH_SECRET=
BETTER_AUTH_URL=http://localhost:3000
```

## If Redis cache

```bash
# Redis connection string. docker-compose.yml provisions this at localhost:6379 in dev.
REDIS_URL=redis://localhost:6379
```

## If MCP entry point

```bash
# No new envs beyond Better Auth — the MCP plugin reuses BETTER_AUTH_SECRET / BETTER_AUTH_URL.
```

## If Resend email

```bash
# Resend API key. Empty = email goes to a Pino dev sink (the outbox still writes a row).
RESEND_API_KEY=
# From-address for transactional mail.
RESEND_FROM=noreply@example.com
# Svix signing secret for verifying Resend webhooks.
RESEND_WEBHOOK_SECRET=
```

## If Sentry (optional — offer if user mentions monitoring)

```bash
# Sentry DSN. Empty = Sentry no-ops in both client + server.
SENTRY_DSN=
```

## If cron jobs

```bash
# Gate for in-process node-cron. Set false in CI and one-shot containers; true on app servers.
CRON_ENABLED=true
```

## Final file shape

After substitution, the `.env.example` looks like:

```bash
# ──────────────────────────────────────────────────────────────
# {{PROJECT_NAME}} — environment configuration
# Copy to .env.local and fill in.
# ──────────────────────────────────────────────────────────────

# App
NEXT_PUBLIC_APP_URL=http://localhost:3000

# Database
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/{{PROJECT_NAME}}

# Auth (Better Auth)
BETTER_AUTH_SECRET=
BETTER_AUTH_URL=http://localhost:3000

# (etc., only the sections matching enabled features)
```

The `src/env.ts` file (using `@t3-oss/env-nextjs`) is the source of truth — it validates these at boot. Keep `.env.example` and `src/env.ts` in sync; if a key is added to one, add to the other.
