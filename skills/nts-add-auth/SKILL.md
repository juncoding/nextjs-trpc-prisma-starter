---
name: nts-add-auth
description: "Add Better Auth to an existing project scaffolded with nextjs-trpc-prisma-starter that initially skipped auth. Use this when the user says 'add auth', 'add login', 'wire Better Auth', 'add user accounts', invokes /nts-add-auth, or starts asking permission/session questions in a project without auth wired. Wires up the Better Auth Prisma adapter, session helper, requirePermission helper, /login page (credentials), the auth route handler at /api/auth/[...all], and the User / Session / Account / Verification Prisma models. Updates the tRPC context to include the session and switches the example router from publicProcedure to protectedProcedure."
---

# Add Better Auth to an existing project

For projects scaffolded without auth that now need it. This is a substantial change — every tRPC procedure becomes auth-gated, and the schema gains four new tables.

## Use when

- User wants user accounts / login / sessions.
- User says "add auth" / "wire Better Auth" / "we need permissions now".
- User invokes `/nts-add-auth`.

## Confirmation flow

Auth is a meaningful schema change. Before writing:

1. Verify project structure (`prisma/schema.prisma`, `src/server/`, `package.json` exist).
2. Confirm auth strategy:
   - **Credentials only (recommended)** — email + password.
   - **Credentials + magic-link** — adds Resend dependency.
   - **Credentials + OAuth providers** (Google, GitHub, etc.) — adds provider configuration.
3. Confirm the user has a place to put the bootstrap admin (sysadmin) — usually the seed script.
4. Show all file changes. Confirm.

## What this skill does

1. Adds `better-auth` to `package.json`.
2. Adds Better Auth's required Prisma models — `User`, `Session`, `Account`, `Verification`.
3. Creates a migration.
4. Creates `src/server/auth/index.ts` with the Better Auth config.
5. Creates `src/server/auth/session.ts` with `requireSession()` and `getSession()` helpers.
6. Creates `src/server/auth/permissions.ts` with `requirePermission()` (RBAC). Adds `Role`, `Permission`, `UserRole`, `RolePermission` Prisma models.
7. Creates `src/app/api/auth/[...all]/route.ts` — Better Auth's catch-all handler.
8. Creates `src/app/(auth)/login/page.tsx` — credentials login form.
9. Updates `src/server/api/trpc.ts` — context now includes session; adds `protectedProcedure`.
10. Updates existing tRPC routers — switches `publicProcedure` to `protectedProcedure` where appropriate.
11. Updates existing services — adds `userId` first parameter + `requirePermission` if not already present.
12. Updates `prisma/seed.ts` to seed default roles + permissions + a bootstrap admin.
13. Updates `CLAUDE.md` to document the auth layer.

## Prisma models to add

```prisma
model User {
  id            String    @id @default(cuid())
  email         String    @unique
  emailVerified Boolean   @default(false)
  name          String?
  image         String?
  isSysadmin    Boolean   @default(false) @map("is_sysadmin")
  status        String    @default("active")
  createdAt     DateTime  @default(now()) @map("created_at")
  updatedAt     DateTime  @updatedAt      @map("updated_at")

  sessions   Session[]
  accounts   Account[]
  userRoles  UserRole[]

  @@map("users")
}

model Session {
  id        String   @id @default(cuid())
  userId    String   @map("user_id")
  token     String   @unique
  expiresAt DateTime @map("expires_at")
  ipAddress String?  @map("ip_address")
  userAgent String?  @map("user_agent")
  createdAt DateTime @default(now()) @map("created_at")
  updatedAt DateTime @updatedAt      @map("updated_at")
  user User @relation(fields: [userId], references: [id], onDelete: Cascade)
  @@map("sessions")
}

model Account {
  id                    String   @id @default(cuid())
  userId                String   @map("user_id")
  accountId             String   @map("account_id")
  providerId            String   @map("provider_id")
  accessToken           String?  @map("access_token")
  refreshToken          String?  @map("refresh_token")
  accessTokenExpiresAt  DateTime? @map("access_token_expires_at")
  refreshTokenExpiresAt DateTime? @map("refresh_token_expires_at")
  scope                 String?
  idToken               String?  @map("id_token")
  password              String?
  createdAt             DateTime @default(now()) @map("created_at")
  updatedAt             DateTime @updatedAt      @map("updated_at")
  user User @relation(fields: [userId], references: [id], onDelete: Cascade)
  @@map("accounts")
}

model Verification {
  id         String   @id @default(cuid())
  identifier String
  value      String
  expiresAt  DateTime @map("expires_at")
  createdAt  DateTime @default(now()) @map("created_at")
  updatedAt  DateTime @updatedAt      @map("updated_at")
  @@map("verifications")
}

model Role {
  id          String           @id @default(cuid())
  name        String           @unique
  description String?
  createdAt   DateTime         @default(now()) @map("created_at")
  permissions RolePermission[]
  users       UserRole[]
  @@map("roles")
}

model Permission {
  id    String           @id @default(cuid())
  scope String           @unique
  roles RolePermission[]
  @@map("permissions")
}

model UserRole {
  userId String @map("user_id")
  roleId String @map("role_id")
  user User @relation(fields: [userId], references: [id], onDelete: Cascade)
  role Role @relation(fields: [roleId], references: [id], onDelete: Cascade)
  @@id([userId, roleId])
  @@map("user_roles")
}

model RolePermission {
  roleId       String @map("role_id")
  permissionId String @map("permission_id")
  role       Role       @relation(fields: [roleId], references: [id], onDelete: Cascade)
  permission Permission @relation(fields: [permissionId], references: [id], onDelete: Cascade)
  @@id([roleId, permissionId])
  @@map("role_permissions")
}
```

## Files to create / modify

### `src/server/auth/index.ts` (new)

```ts
import "server-only";
import { betterAuth } from "better-auth";
import { prismaAdapter } from "better-auth/adapters/prisma";
import { nextCookies } from "better-auth/next-js";
import { db } from "@/server/db/client";

export const auth = betterAuth({
  database: prismaAdapter(db, { provider: "postgresql" }),
  emailAndPassword: { enabled: true },
  plugins: [nextCookies()],
});
```

### `src/server/auth/session.ts` (new)

```ts
import "server-only";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { auth } from "./index";

export async function getSession() {
  return auth.api.getSession({ headers: await headers() });
}

export async function requireSession() {
  const session = await getSession();
  if (!session) redirect("/login");
  return session;
}
```

### `src/server/auth/permissions.ts` (new)

```ts
import "server-only";
import { db } from "@/server/db/client";
import { ForbiddenError } from "@/server/lib/errors";

export type PermissionScope = string; // tighten with a union once you have your scope catalog

export async function requirePermission(userId: string, scope: PermissionScope) {
  const user = await db.user.findUnique({ where: { id: userId }, select: { isSysadmin: true } });
  if (user?.isSysadmin) return;

  const allowed = await db.rolePermission.findFirst({
    where: { role: { users: { some: { userId } } }, permission: { scope } },
    select: { permissionId: true },
  });
  if (!allowed) throw new ForbiddenError(`Missing permission: ${scope}`);
}
```

### `src/app/api/auth/[...all]/route.ts` (new)

```ts
import { auth } from "@/server/auth";
import { toNextJsHandler } from "better-auth/next-js";

export const { GET, POST } = toNextJsHandler(auth.handler);
```

### `src/app/(auth)/login/page.tsx` (new)

Standard credentials form — name field + email + password — POSTs to Better Auth's `/api/auth/sign-in/email`. Use the Better Auth client (`authClient.signIn.email({...})`) if you prefer.

### Update `src/server/api/trpc.ts`

Add session to context, expose `protectedProcedure`. See `assets/trpc-server.ts.template` from `scaffold-internal-tool` — the `{{#IF_AUTH}}` branch.

### Update existing routers and services

Walk every router file in `src/server/api/routers/` and replace `publicProcedure` with `protectedProcedure` where the procedure shouldn't be anonymous. Walk every service and verify the `userId`-first signature + `requirePermission` call.

### Seed roles and permissions

Add to `prisma/seed.ts`:

```ts
async function seedRolesAndPermissions() {
  const scopes = ["customers:read", "customers:write", /* ... */];

  await Promise.all(
    scopes.map((scope) =>
      db.permission.upsert({ where: { scope }, update: {}, create: { scope } })
    )
  );

  const admin = await db.role.upsert({
    where: { name: "admin" }, update: {}, create: { name: "admin" },
  });
  // Wire all permissions to admin role
  for (const scope of scopes) {
    const perm = await db.permission.findUniqueOrThrow({ where: { scope } });
    await db.rolePermission.upsert({
      where: { roleId_permissionId: { roleId: admin.id, permissionId: perm.id } },
      update: {}, create: { roleId: admin.id, permissionId: perm.id },
    });
  }
}
```

## Verification

```bash
pnpm install
pnpm prisma migrate dev --name add_auth
pnpm db:seed
pnpm tsc --noEmit
pnpm build
```

Then guide the user to:

1. Sign up a first user via the login page.
2. Manually update the User row in Prisma Studio to set `isSysadmin = true`.
3. Sign in — they should now have access to everything.

The bootstrap-admin step is manual to keep this skill stack-agnostic. Document the step in `CLAUDE.md`.
