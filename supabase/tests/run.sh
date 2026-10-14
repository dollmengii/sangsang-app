#!/usr/bin/env bash
# 빈 Postgres 데이터베이스에 마이그레이션, 태그, 흐름 테스트를 차례로 돌린다.
# 사용: PGURL=postgres://postgres@localhost:5432/postgres supabase/tests/run.sh
set -euo pipefail
cd "$(dirname "$0")/.."
psql "$PGURL" -q -v ON_ERROR_STOP=1 \
  -f tests/supabase_shim.sql \
  $(printf -- '-f %s ' migrations/*.sql) \
  -f seed.sql \
  -c "grant select, insert, update, delete on all tables in schema public to authenticated; grant usage on all sequences in schema public to authenticated;"
psql "$PGURL" -q -v ON_ERROR_STOP=1 -f tests/reveal_flow.sql
