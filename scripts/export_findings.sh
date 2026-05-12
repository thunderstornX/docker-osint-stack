#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# export_findings.sh — pg_dump the audit log and GPG-encrypt the
# result. Output lands in ./exports/audit-log-<timestamp>.sql.gpg.
#
# Symmetric (passphrase) encryption deliberately: this is for cold
# storage of an internal investigation, not for sending to third
# parties. Passphrase is taken from EXPORT_GPG_PASSPHRASE in
# config/.env; the script refuses to run without one.
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

ENV_FILE="${REPO_ROOT}/config/.env"
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: ${ENV_FILE} not found." >&2
  exit 2
fi
set -a
# shellcheck source=/dev/null
source "${ENV_FILE}"
set +a

: "${EXPORT_GPG_PASSPHRASE:?EXPORT_GPG_PASSPHRASE must be set in config/.env}"
: "${POSTGRES_USER:?POSTGRES_USER missing in config/.env}"
: "${POSTGRES_DB:?POSTGRES_DB missing in config/.env}"

if ! command -v gpg >/dev/null 2>&1; then
  echo "ERROR: gpg not in PATH. Install gnupg before exporting." >&2
  exit 3
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
SQL_OUT="${REPO_ROOT}/exports/audit-log-${STAMP}.sql"
GPG_OUT="${SQL_OUT}.gpg"

mkdir -p "${REPO_ROOT}/exports"

echo "[export] pg_dump → ${SQL_OUT}"
docker exec dos-postgres \
    pg_dump --no-owner --no-privileges \
            --username="${POSTGRES_USER}" \
            "${POSTGRES_DB}" > "${SQL_OUT}"

echo "[export] gpg symmetric → ${GPG_OUT}"
gpg --batch --yes --quiet \
    --passphrase "${EXPORT_GPG_PASSPHRASE}" \
    --cipher-algo AES256 \
    --symmetric \
    --output "${GPG_OUT}" \
    "${SQL_OUT}"

# Wipe the plaintext as soon as the ciphertext lands.
if command -v shred >/dev/null 2>&1; then
  shred --remove=unlink --zero --iterations=3 "${SQL_OUT}"
else
  rm -f -- "${SQL_OUT}"
fi

SIZE=$(wc -c <"${GPG_OUT}")
echo "[export] OK — ${GPG_OUT} (${SIZE} bytes)"
