# End-to-end tests with Playwright

The thin top of the pyramid. A few flows that prove the app works as a whole — not a substitute for service tests.

## When to add e2e tests

Add one per critical user journey:
- Login → dashboard renders.
- Per-module happy path (create → list → detail → update).
- Cross-module flows (quote → award → SO appears).

Don't add e2e tests for every form validation or every error message. That's expensive friction for low return.

## Setup

```bash
pnpm add -D @playwright/test
npx playwright install --with-deps chromium
```

`playwright.config.ts`:

```ts
import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/e2e",
  use: {
    baseURL: process.env.E2E_BASE_URL || "http://localhost:3000",
    headless: true,
  },
  webServer: {
    command: "pnpm dev",
    url: "http://localhost:3000",
    reuseExistingServer: !process.env.CI,
  },
});
```

## The shape

```ts
// tests/e2e/login.spec.ts
import { test, expect } from "@playwright/test";

test("login lands on dashboard", async ({ page }) => {
  await page.goto("/login");
  await page.getByLabel("Email").fill("test-user@example.com");
  await page.getByLabel("Password").fill("test-password");
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page).toHaveURL("/");
  await expect(page.getByText("Dashboard")).toBeVisible();
});
```

## Seeding test data

The e2e suite needs a pre-seeded user. Either:

- **Reset + seed before the run** via a `globalSetup` script that calls `pnpm prisma migrate reset --force` against a `TEST_DATABASE_URL`.
- **Use a known seed** that's deterministic and idempotent in `prisma/seed.ts`.

Pick one and stick to it. Don't let e2e tests mutate the dev database.

## Auth shortcut

Logging in via the form is slow. Set the session cookie directly:

```ts
// tests/e2e/helpers/auth.ts
import { Page } from "@playwright/test";

export async function loginAs(page: Page, userId: string) {
  // Issue a session via Better Auth's admin API or directly via Prisma.
  const sessionToken = await issueTestSession(userId);
  await page.context().addCookies([{
    name: "better-auth.session_token",
    value: sessionToken,
    domain: "localhost",
    path: "/",
  }]);
}
```

Then most tests start logged in instantly:

```ts
test.beforeEach(async ({ page }) => {
  await loginAs(page, "test-user");
});
```

## What to assert

- **URLs and visible text** — `expect(page).toHaveURL(...)`, `expect(page.getByText(...)).toBeVisible()`.
- **Side effects via API** — after a mutation, hit a tRPC procedure (via fetch) to verify the DB state, OR navigate to a detail page and assert its content.

Don't snapshot the DOM. It's brittle. Use accessible selectors (`getByRole`, `getByLabel`) so the test also doubles as a smoke check on accessibility.

## Anti-patterns

- **Testing every CRUD form via e2e.** Cover create + list + one update. Service tests catch the rest.
- **Sleeping with `page.waitForTimeout`.** Use `waitFor` against an actual condition (visible text, URL match).
- **Hard-coded test data that other tests depend on.** Each test sets up its own minimum state, or uses isolated fixtures.

## When e2e tests start to hurt

If e2e tests get flaky or slow:
- Move assertions to component tests (React Testing Library).
- Move business-logic checks to service tests.
- Keep e2e to "this URL renders and a button works." Don't push it further.
