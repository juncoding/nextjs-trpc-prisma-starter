---
name: nts-add-cache
description: "Retrofit Redis caching into an existing project scaffolded with nextjs-trpc-prisma-starter. Use this when the user wants to add Redis, add a cache layer, speed up frequent reads, share cache across processes, or any 'add caching to this project' request. Adds ioredis, a docker-compose redis service, a typed cache helper at src/server/lib/cache.ts, REDIS_URL env, and updates CLAUDE.md to reflect the new dependency. Refuses to run on projects that don't have the scaffolded structure."
---

# Add Redis cache to an existing project

For projects scaffolded with `nextjs-trpc-prisma-starter` that didn't enable cache at scaffold time and now want it.

## Use when

- User says "add Redis" / "add caching" / "speed up this query" with the implication that in-process cache isn't enough.
- A specific service method needs cross-process cache (multiple app containers / horizontal scaling).
- User invokes `/nts-add-cache`.

Do NOT use when:

- The project isn't scaffolded by this plugin — the file layout assumptions won't hold. Refuse gracefully and explain.
- The user wants Next.js's built-in `unstable_cache` / `cacheTag` — this plugin uses SPA mode, so those aren't relevant.

## What this skill does

Modifies the existing project in place. After running:

1. `ioredis` added to `package.json` dependencies.
2. `redis` service added to `docker-compose.yml`.
3. `REDIS_URL` added to `.env.example` and `src/env.ts`.
4. New file `src/server/lib/cache.ts` with a typed `cache.get<T>()` / `cache.set()` / `cache.invalidate()` helper.
5. `CLAUDE.md` updated to mention the new cache layer.
6. Optional: a sample service method wrapped in the cache helper, so the user has a worked example.

## Confirmation flow

Before writing anything, confirm:

1. Project root path (default: cwd).
2. Verify `package.json`, `CLAUDE.md`, and `docker-compose.yml` exist — refuse if they don't.
3. Show the user the list of files that will change.
4. Confirm.

## File changes

### `package.json`

Add to `dependencies`:

```json
"ioredis": "^5"
```

### `docker-compose.yml`

Add a `redis` service alongside postgres:

```yaml
  redis:
    image: redis:7-alpine
    container_name: {{PROJECT_NAME}}-redis
    ports: ["6379:6379"]
    volumes: [redis-data:/data]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5
```

And add `redis-data:` to the `volumes:` block at the bottom.

### `.env.example`

Append (with section header):

```bash

# Cache
REDIS_URL=redis://localhost:6379
```

### `src/env.ts`

Add `REDIS_URL: z.string().url()` to the server schema and `REDIS_URL: process.env.REDIS_URL` to runtime.

### `src/server/lib/cache.ts` (new)

```ts
import "server-only";
import Redis from "ioredis";
import { env } from "@/env";

const redis = new Redis(env.REDIS_URL, { lazyConnect: true, maxRetriesPerRequest: 3 });
// Lazy connect — the connection only opens on first command.

interface CacheOpts {
  /** TTL in seconds. Required — pick a value, no infinite caching. */
  ttlSeconds: number;
}

export const cache = {
  async get<T>(key: string): Promise<T | null> {
    const raw = await redis.get(key);
    if (!raw) return null;
    try { return JSON.parse(raw) as T; } catch { return null; }
  },

  async set<T>(key: string, value: T, opts: CacheOpts) {
    await redis.set(key, JSON.stringify(value), "EX", opts.ttlSeconds);
  },

  async invalidate(key: string) {
    await redis.del(key);
  },

  /** Pattern-based invalidation. Use sparingly — KEYS is O(N) on the keyspace. */
  async invalidatePattern(pattern: string) {
    const keys = await redis.keys(pattern);
    if (keys.length > 0) await redis.del(...keys);
  },

  /** Memoize an async fn. Cache hit returns immediately; miss runs `fn` and stores. */
  async memo<T>(key: string, opts: CacheOpts, fn: () => Promise<T>): Promise<T> {
    const cached = await cache.get<T>(key);
    if (cached !== null) return cached;
    const fresh = await fn();
    await cache.set(key, fresh, opts);
    return fresh;
  },
};
```

### `CLAUDE.md`

Locate the stack section and add `Cache:` line. Locate the "Useful commands" section and add `docker compose up redis` if not present.

## Worked example to show the user

After the install lands, show this pattern as the "how to actually use it" example:

```ts
// src/server/modules/exchange-rate/exchange-rate.service.ts
import { cache } from "@/server/lib/cache";

export const exchangeRateService = {
  async getRateMap(userId: string) {
    await requirePermission(userId, "exchange-rate:read");
    return cache.memo("exchange-rate:map", { ttlSeconds: 300 }, async () => {
      const rows = await db.exchangeRate.findMany();
      return Object.fromEntries(rows.map(r => [r.currency, r.rate]));
    });
  },

  async updateRate(userId: string, currency: string, rate: number) {
    await requirePermission(userId, "exchange-rate:write");
    await db.$transaction(async (tx) => {
      await tx.exchangeRate.upsert({ where: { currency }, create: { currency, rate }, update: { rate } });
      await auditLog(tx, { userId, action: "exchange-rate.updated", entityId: currency });
    });
    await cache.invalidate("exchange-rate:map");   // invalidate after the tx commits
  },
};
```

Note: invalidate AFTER the transaction commits, not inside it — if the tx rolls back, you'd otherwise have invalidated a stale entry pointlessly.

## Verification

After writing all files, run:

```bash
pnpm install
docker compose up -d redis
pnpm tsc --noEmit
```

Report any failures. Don't try to run the app — the user owns that.
