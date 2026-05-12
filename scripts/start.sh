#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# start.sh — bring the stack up and wait for every service to be
# healthy. Exits non-zero if any healthcheck never goes green.
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

ENV_FILE="${REPO_ROOT}/config/.env"
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: ${ENV_FILE} not found." >&2
  echo "       Copy config/.env.example to config/.env and fill in." >&2
  exit 2
fi

# Refuse to start with the default password still in place.
if grep -qE '^POSTGRES_PASSWORD=change_me_before_first_boot' "${ENV_FILE}"; then
  echo "ERROR: POSTGRES_PASSWORD is still the default. Edit config/.env." >&2
  exit 3
fi

# Resolve compose binary. Prefer the v2 plugin (`docker compose …`);
# fall back to v1 (`docker-compose …`) only when v2 is absent.
if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose --env-file "${ENV_FILE}")
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose --env-file "${ENV_FILE}")
else
  echo "ERROR: neither 'docker compose' (plugin) nor 'docker-compose' (v1) found." >&2
  exit 4
fi

echo "[start] bringing up the stack…"
"${COMPOSE[@]}" up -d --remove-orphans

# ─── wait loop ───────────────────────────────────────────────────
# Each service has its own HEALTHCHECK; we poll docker inspect.
SERVICES=(dos-postgres dos-spiderfoot dos-nginx)
DEADLINE=$(( SECONDS + 180 ))    # 3-minute hard cap

for svc in "${SERVICES[@]}"; do
  echo -n "[start] waiting for ${svc}: "
  while :; do
    status=$(docker inspect --format='{{.State.Health.Status}}' "${svc}" 2>/dev/null || echo "missing")
    case "${status}" in
      healthy)
        echo "healthy"
        break
        ;;
      missing)
        echo "container '${svc}' not present — did the build fail?" >&2
        exit 5
        ;;
      *)
        if (( SECONDS > DEADLINE )); then
          echo
          echo "ERROR: ${svc} did not become healthy within the deadline." >&2
          docker inspect --format='  status={{.State.Health.Status}} log={{range .State.Health.Log}}{{.Output}}{{end}}' "${svc}" >&2 || true
          exit 6
        fi
        echo -n "."
        sleep 3
        ;;
    esac
  done
done

echo
echo "[start] all services healthy."
echo "[start] SpiderFoot UI is reachable at  http://${NGINX_HOST_BIND:-127.0.0.1}:${NGINX_HOST_PORT:-8080}/"
echo "[start] (the host port is bound to localhost by default; do NOT expose to 0.0.0.0"
echo "[start]  without basic-auth + TLS in front)."
