#!/usr/bin/env bash
#
# check-conventions.sh
#
# Mechanical checks for projects scaffolded with nextjs-trpc-prisma-starter.
# Outputs tagged findings the review-project skill parses.
# Always exits 0 — the skill interprets results, not the shell exit code.
#
# Usage: run from the project root.
#   bash <path-to-plugin>/skills/review-project/scripts/check-conventions.sh

set -u

# ── Sanity check the project structure ────────────────────────────────────

require_path() {
  if [ ! -e "$1" ]; then
    echo "STRUCTURE_FAIL: missing $1"
    return 1
  fi
}

structure_ok=true
require_path "src/server/api/trpc.ts" || structure_ok=false
require_path "src/server/modules" || structure_ok=false
require_path "src/app/api/trpc/[trpc]/route.ts" || structure_ok=false
require_path "CLAUDE.md" || structure_ok=false

if [ "$structure_ok" = false ]; then
  echo ""
  echo "=== Summary ==="
  echo "Structure check failed. This project does not match the layout that nextjs-trpc-prisma-starter expects."
  echo "If the project is on a different stack, this skill is not the right tool."
  exit 0
fi

# ── 1. Files in src/server/ missing import "server-only"; ────────────────
# Skip *.types.ts, *.schema.ts (pure types / Zod — server-only is unneeded noise)

missing_server_only=0
total_server=0
while IFS= read -r f; do
  total_server=$((total_server + 1))
  case "$f" in
    *.types.ts|*.schema.ts|*.spec.ts|*.spec.tsx) continue ;;
  esac
  if ! grep -q '^import "server-only"' "$f" 2>/dev/null && ! grep -q "^import 'server-only'" "$f" 2>/dev/null; then
    echo "MISSING_SERVER_ONLY: $f"
    missing_server_only=$((missing_server_only + 1))
  fi
done < <(find src/server -type f \( -name "*.ts" -o -name "*.tsx" \) 2>/dev/null)

# ── 2. DB client imported inside src/app/ ─────────────────────────────────

db_in_app=$(grep -rn 'from "@/server/db' src/app/ 2>/dev/null || true)
if [ -n "$db_in_app" ]; then
  while IFS= read -r line; do
    echo "DB_IN_APP: $line"
  done <<< "$db_in_app"
fi
db_in_app_count=$(echo -n "$db_in_app" | grep -c '^' || true)

# ── 3. "use server" directives anywhere in src/ ───────────────────────────

server_actions=$(grep -rn '^"use server"\|^'"'"'use server'"'"'' src/ 2>/dev/null || true)
if [ -n "$server_actions" ]; then
  while IFS= read -r line; do
    echo "SERVER_ACTION: $line"
  done <<< "$server_actions"
fi
server_action_count=$(echo -n "$server_actions" | grep -c '^' || true)

# ── 4. Wrong cache primitives for SPA mode ────────────────────────────────

wrong_cache=$(grep -rn 'revalidateTag\|revalidatePath\|updateTag\|"use cache"\|cacheTag\s*(\|cacheLife\s*(' src/ 2>/dev/null || true)
if [ -n "$wrong_cache" ]; then
  while IFS= read -r line; do
    echo "WRONG_CACHE_PRIMITIVE: $line"
  done <<< "$wrong_cache"
fi
wrong_cache_count=$(echo -n "$wrong_cache" | grep -c '^' || true)

# ── 5. tRPC routers importing the db client (should call services) ────────

router_has_db=$(grep -rn 'from "@/server/db' src/server/api/routers/ 2>/dev/null || true)
if [ -n "$router_has_db" ]; then
  while IFS= read -r line; do
    echo "ROUTER_HAS_DB: $line"
  done <<< "$router_has_db"
fi
router_has_db_count=$(echo -n "$router_has_db" | grep -c '^' || true)

# ── 6. tRPC procedure bodies > 5 lines (heuristic — easy false positives) ─
# Looks for `.query(` or `.mutation(` opens and counts braces until close.
# Reports cases that span more than 5 lines. The skill verifies.

router_bloat=0
for f in $(find src/server/api/routers -type f -name "*.ts" 2>/dev/null); do
  awk '
    /\.(query|mutation)\(/ {
      start_line = NR
      depth = 0
      tracking = 1
    }
    tracking == 1 {
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (c == "(" || c == "{") depth++
        else if (c == ")" || c == "}") {
          depth--
          if (depth == 0) {
            if (NR - start_line > 5) {
              printf "ROUTER_BLOAT: %s:%d (procedure body spans %d lines)\n", FILENAME, start_line, (NR - start_line + 1)
            }
            tracking = 0
            break
          }
        }
      }
    }
  ' "$f"
done
router_bloat_count=$(grep -c '^ROUTER_BLOAT:' <<< "$(for f in $(find src/server/api/routers -type f -name "*.ts" 2>/dev/null); do
  awk '
    /\.(query|mutation)\(/ {
      start_line = NR
      depth = 0
      tracking = 1
    }
    tracking == 1 {
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (c == "(" || c == "{") depth++
        else if (c == ")" || c == "}") {
          depth--
          if (depth == 0) {
            if (NR - start_line > 5) {
              printf "ROUTER_BLOAT: %s:%d (procedure body spans %d lines)\n", FILENAME, start_line, (NR - start_line + 1)
            }
            tracking = 0
            break
          }
        }
      }
    }
  ' "$f"
done)" 2>/dev/null || echo 0)

# ── 7. Service mutations without requirePermission (regex heuristic) ──────
# Looks for service methods named create/update/delete/cancel/etc. and checks
# whether `requirePermission` appears within the next ~15 lines of that method.

service_no_permission=0
mutation_no_audit=0
no_transaction=0

mutation_verbs="create|update|delete|remove|cancel|award|markSent|markPaid|markComplete|approve|reject|withdraw|publish|archive|restore|transition"

for f in $(find src/server/modules -type f -name "*.service.ts" 2>/dev/null); do
  awk -v verbs="$mutation_verbs" '
    BEGIN {
      verb_pat = "(" verbs ")"
    }
    {
      # Detect start of a mutation-shaped method:  async create(userId: ...)
      if (match($0, "async +" verb_pat "[A-Za-z]*\\(.*userId")) {
        method_start = NR
        method_name = $0
        sub(/.*async +/, "", method_name)
        sub(/\(.*/, "", method_name)

        # Capture the next 25 lines as the method body context
        body = ""
        for (lookahead = 0; lookahead < 25; lookahead++) {
          if ((getline next_line) > 0) {
            body = body "\n" next_line
            NR_seen = NR
          } else break
        }

        if (body !~ /requirePermission/) {
          printf "SERVICE_NO_PERMISSION: %s:%d:%s\n", FILENAME, method_start, method_name
        }
        if (body !~ /auditLog/) {
          printf "MUTATION_NO_AUDIT: %s:%d:%s\n", FILENAME, method_start, method_name
        }
        # If method touches >1 DB statement, expect a $transaction
        db_calls = gsub(/(db|tx|prisma)\.[a-zA-Z]+\.(create|update|delete|upsert|deleteMany|updateMany|createMany)/, "&", body)
        if (db_calls > 1 && body !~ /\$transaction/) {
          printf "NO_TRANSACTION: %s:%d:%s (%d write statements, no $transaction)\n", FILENAME, method_start, method_name, db_calls
        }
      }
    }
  ' "$f"
done

# (Recount after the fact for the summary)
service_no_permission=$(grep -c '^SERVICE_NO_PERMISSION:' <<< "$(for f in $(find src/server/modules -type f -name "*.service.ts" 2>/dev/null); do
  awk -v verbs="$mutation_verbs" '
    BEGIN { verb_pat = "(" verbs ")" }
    {
      if (match($0, "async +" verb_pat "[A-Za-z]*\\(.*userId")) {
        method_start = NR
        method_name = $0
        sub(/.*async +/, "", method_name)
        sub(/\(.*/, "", method_name)
        body = ""
        for (lookahead = 0; lookahead < 25; lookahead++) {
          if ((getline next_line) > 0) body = body "\n" next_line
          else break
        }
        if (body !~ /requirePermission/) printf "SERVICE_NO_PERMISSION: %s:%d:%s\n", FILENAME, method_start, method_name
      }
    }
  ' "$f"
done)" 2>/dev/null || echo 0)

# ── 8. Foreign state-management libraries ─────────────────────────────────

state_libs=""
if [ -f package.json ]; then
  for lib in redux "@reduxjs/toolkit" zustand jotai valtio recoil mobx mobx-react; do
    if grep -q "\"$lib\"" package.json 2>/dev/null; then
      state_libs="$state_libs $lib"
      echo "STATE_LIB: $lib"
    fi
  done
fi

# ── 9. Bare `throw new Error(` in services (prefer domain errors) ─────────

raw_errors=$(grep -rn 'throw new Error(' src/server/modules/ 2>/dev/null || true)
if [ -n "$raw_errors" ]; then
  while IFS= read -r line; do
    echo "RAW_ERROR: $line"
  done <<< "$raw_errors"
fi
raw_error_count=$(echo -n "$raw_errors" | grep -c '^' || true)

# ── 10. console.log in src/server/ ────────────────────────────────────────

console_logs=$(grep -rn '\bconsole\.\(log\|info\|warn\|error\)' src/server/ 2>/dev/null || true)
if [ -n "$console_logs" ]; then
  while IFS= read -r line; do
    echo "CONSOLE_LOG: $line"
  done <<< "$console_logs"
fi
console_log_count=$(echo -n "$console_logs" | grep -c '^' || true)

# ── 11. `as any` casts in src/server/ ─────────────────────────────────────

any_casts=$(grep -rn ' as any\b' src/server/ 2>/dev/null || true)
if [ -n "$any_casts" ]; then
  while IFS= read -r line; do
    echo "AS_ANY: $line"
  done <<< "$any_casts"
fi
any_cast_count=$(echo -n "$any_casts" | grep -c '^' || true)

# ── Summary ───────────────────────────────────────────────────────────────

echo ""
echo "=== Summary ==="
echo "server_files_total: $total_server"
echo "missing_server_only: $missing_server_only"
echo "db_in_app: $db_in_app_count"
echo "server_actions: $server_action_count"
echo "wrong_cache_primitive: $wrong_cache_count"
echo "router_has_db: $router_has_db_count"
echo "service_no_permission: $service_no_permission"
echo "raw_errors_in_services: $raw_error_count"
echo "console_logs_in_server: $console_log_count"
echo "as_any_in_server: $any_cast_count"
echo "foreign_state_libs:$state_libs"
echo ""
echo "(Heuristic findings — SERVICE_NO_PERMISSION, MUTATION_NO_AUDIT, NO_TRANSACTION — must be verified by reading the flagged file. False positives possible on pure-read methods named with mutation-like verbs.)"

exit 0
