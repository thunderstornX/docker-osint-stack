#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# teardown.sh — stop the stack, remove volumes, and (with --shred)
# wipe local exports/ artefacts using GNU shred.
#
# Defaults are intentionally destructive:
#   * containers are removed
#   * named volumes are removed (postgres-data, spiderfoot-data)
# Pass --keep-volumes if you need to preserve the audit log between
# sessions.
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

ENV_FILE="${REPO_ROOT}/config/.env"

KEEP_VOLUMES=0
SHRED_EXPORTS=0
for arg in "$@"; do
  case "${arg}" in
    --keep-volumes) KEEP_VOLUMES=1 ;;
    --shred)        SHRED_EXPORTS=1 ;;
    -h|--help)
      cat <<'USAGE'
Usage: teardown.sh [--keep-volumes] [--shred]

  --keep-volumes   Preserve postgres-data / spiderfoot-data named volumes.
  --shred          GNU-shred every file under ./exports/ before unlinking.

Default (no flags): containers + volumes are removed; exports/ kept.
USAGE
      exit 0 ;;
    *) echo "unknown arg: ${arg}" >&2; exit 2 ;;
  esac
done

if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose --env-file "${ENV_FILE}")
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose --env-file "${ENV_FILE}")
else
  echo "ERROR: neither 'docker compose' (plugin) nor 'docker-compose' (v1) found." >&2
  exit 4
fi

echo "[teardown] stopping containers…"
if (( KEEP_VOLUMES == 1 )); then
  "${COMPOSE[@]}" down --remove-orphans
else
  "${COMPOSE[@]}" down --remove-orphans --volumes
fi

if (( SHRED_EXPORTS == 1 )); then
  if command -v shred >/dev/null 2>&1; then
    shopt -s nullglob
    files=( "${REPO_ROOT}/exports/"*.gpg
            "${REPO_ROOT}/exports/"*.tar.gz
            "${REPO_ROOT}/exports/"*.sql )
    if (( ${#files[@]} == 0 )); then
      echo "[teardown] --shred: nothing under exports/ to shred."
    else
      echo "[teardown] shredding ${#files[@]} export artefact(s)…"
      shred --remove=unlink --zero --iterations=3 "${files[@]}"
    fi
  else
    echo "[teardown] --shred: 'shred' not found in PATH; skipping." >&2
  fi
fi

echo "[teardown] done."
