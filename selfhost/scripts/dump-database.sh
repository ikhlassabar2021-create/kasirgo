#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Dump database KasirGo (PostgreSQL) menjadi file SQL portable untuk self-host.
#
# Kebutuhan: `pg_dump` (paket postgresql-client) dan kredensial database.
#
# Kredensial lewat environment (standar libpq):
#   PGHOST   = host (mis. aws-0-<region>.pooler.supabase.com)
#   PGPORT   = 5432
#   PGDATABASE = postgres
#   PGUSER     = postgres.<ref>
#   PGPASSWORD = ...
#   Atau cukup set `DATABASE_URL`.
#
# Output (default `selfhost/database/`):
#   01-schema.sql       DDL schema (public auth storage)
#   02-data-public.sql  INSERT data schema public
#   03-data-auth.sql    INSERT data schema auth (termasuk auth.users = akun login)
# =============================================================================

OUT_DIR="${1:-selfhost/database}"
mkdir -p "$OUT_DIR"

# Ekstrak DATABASE_URL bila diset agar variabel libpq terisi.
if [[ -n "${DATABASE_URL:-}" ]]; then
  # Format: postgresql://user:pass@host:port/dbname
  url="${DATABASE_URL#postgresql://}"
  user="$(echo "$url" | cut -d: -f1)"
  rest="$(echo "$url" | cut -d@ -f2-)"
  pass="$(echo "$url" | cut -d@ -f1 | cut -d: -f2-)"
  hostport="${rest%%/*}"
  db="${rest#*/}"
  export PGUSER="$user"
  export PGPASSWORD="$pass"
  export PGHOST="${hostport%%:*}"
  export PGPORT="${hostport##*:}"
  export PGDATABASE="$db"
fi

: "${PGHOST:?Set PGHOST atau DATABASE_URL}"
: "${PGDATABASE:?Set PGDATABASE atau DATABASE_URL}"
: "${PGUSER:?Set PGUSER atau DATABASE_URL}"

echo ">> Dump schema (public, auth, storage) -> 01-schema.sql"
pg_dump --no-owner --no-acl --clean --if-exists --schema-only \
  --schema=public --schema=auth --schema=storage \
  -f "$OUT_DIR/01-schema.sql"

echo ">> Dump data public -> 02-data-public.sql"
pg_dump --no-owner --no-acl --column-inserts --data-only \
  --schema=public \
  -f "$OUT_DIR/02-data-public.sql"

echo ">> Dump data auth (akun login) -> 03-data-auth.sql"
pg_dump --no-owner --no-acl --column-inserts --data-only \
  --schema=auth \
  -f "$OUT_DIR/03-data-auth.sql"

echo ">> Selesai. File di: $OUT_DIR"
ls -la "$OUT_DIR"