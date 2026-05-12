#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# test_stack.sh — end-to-end smoke test.
#
# Brings the stack up, asserts each service responds, exercises the
# audit-log schema, runs theHarvester --help via the one-shot
# profile, then tears the stack down. Exit 0 only on full pass.
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

ENV_FILE="${REPO_ROOT}/config/.env"
RESULTS_DIR="${REPO_ROOT}/results"
mkdir -p "${RESULTS_DIR}"
LOG="${RESULTS_DIR}/test_stack.log"
: > "${LOG}"

passed=0
failed=0

step() {
  local name="$1"; shift
  echo -n "[test] ${name} … "
  if "$@" >>"${LOG}" 2>&1; then
    echo "PASS"
    passed=$((passed + 1))
  else
    echo "FAIL"
    failed=$((failed + 1))
    return 1
  fi
}

cleanup() {
  echo "[test] tearing down…"
  bash scripts/teardown.sh >>"${LOG}" 2>&1 || true
}
trap cleanup EXIT

# ── 1. Pre-flight ───────────────────────────────────────────────
step "compose syntax"          docker compose --env-file "${ENV_FILE}" config --quiet
step "env file present"        test -f "${ENV_FILE}"

# ── 2. Bring up the long-running services ───────────────────────
step "bring stack up"          bash scripts/start.sh

# ── 3. Service-level assertions ─────────────────────────────────
step "postgres ready"          docker exec dos-postgres pg_isready -U "${POSTGRES_USER:-osint}" -d "${POSTGRES_DB:-osint_audit}"

step "spiderfoot HTTP 200" \
  bash -c 'docker exec dos-spiderfoot curl --silent --fail --output /dev/null --write-out "%{http_code}" http://127.0.0.1:5001/ | grep -q "^200$"'

step "nginx /healthz reachable" \
  bash -c 'curl --silent --fail --max-time 5 http://127.0.0.1:8080/healthz | grep -q "^ok$"'

step "nginx → spiderfoot proxy works" \
  bash -c 'curl --silent --fail --max-time 10 --output /dev/null --write-out "%{http_code}" http://127.0.0.1:8080/ | grep -q "^200$"'

# ── 4. Audit-log schema present ─────────────────────────────────
expected_tables="findings investigation_sessions raw_outputs tool_invocations"
step "audit-log tables exist" \
  bash -c "
    set -e
    found=\$(docker exec -e PGPASSWORD=\"\${POSTGRES_PASSWORD}\" dos-postgres \
        psql -U \"\${POSTGRES_USER:-osint}\" -d \"\${POSTGRES_DB:-osint_audit}\" -At \
        -c \"SELECT table_name FROM information_schema.tables \
             WHERE table_schema='public' \
             AND table_name IN ('investigation_sessions','tool_invocations','findings','raw_outputs') \
             ORDER BY table_name\" \
        | tr '\\n' ' ' | sed 's/ \$//')
    test \"\$found\" = '${expected_tables}'
  "

# ── 5. End-to-end audit-log round trip ──────────────────────────
# One CTE statement exercises all three tables in dependency order.
step "audit-log insert round trip" \
  bash -c "
    docker exec -e PGPASSWORD=\"\${POSTGRES_PASSWORD}\" dos-postgres \
      psql -U \"\${POSTGRES_USER:-osint}\" -d \"\${POSTGRES_DB:-osint_audit}\" -At -v ON_ERROR_STOP=1 -c \"
        WITH s AS (
          INSERT INTO investigation_sessions
            (session_tag, operator, authorisation, scope_summary)
          VALUES ('smoke-test', 'ci', 'self-test', 'smoke test session')
          RETURNING session_id
        ),
        i AS (
          INSERT INTO tool_invocations (session_id, tool, target)
          SELECT session_id, 'spiderfoot', 'example.test' FROM s
          RETURNING invocation_id
        )
        INSERT INTO findings (invocation_id, entity_type, entity_value, severity)
        SELECT invocation_id, 'subdomain', 'www.example.test', 'info' FROM i
        RETURNING finding_id;
      \" | grep -E '^[0-9]+\$'
  "

# ── 6. theHarvester one-shot path is callable ───────────────────
step "theHarvester --help via oneshot profile" \
  bash -c "docker compose --env-file '${ENV_FILE}' --profile oneshot run --rm harvester -h \
            | grep -qi 'theHarvester'"

# ── 7. Summary ─────────────────────────────────────────────────
echo
echo "[test] ${passed} pass, ${failed} fail"
test "${failed}" = "0"
