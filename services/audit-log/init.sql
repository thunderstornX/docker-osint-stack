-- ─────────────────────────────────────────────────────────────────
-- docker-osint-stack — audit-log schema
-- Loaded by the official postgres image via /docker-entrypoint-initdb.d/
-- on first container start. Idempotent: only runs against an empty volume.
-- ─────────────────────────────────────────────────────────────────

BEGIN;

-- Investigation sessions: one row per engagement / question / case.
-- Lets the analyst answer "what were we doing at 02:14 last Tuesday".
CREATE TABLE IF NOT EXISTS investigation_sessions (
    session_id      BIGSERIAL PRIMARY KEY,
    session_tag     TEXT NOT NULL,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at        TIMESTAMPTZ,
    operator        TEXT NOT NULL,
    authorisation   TEXT NOT NULL,            -- ticket / engagement letter ref
    scope_summary   TEXT NOT NULL,
    notes           TEXT,
    CONSTRAINT session_tag_nonempty CHECK (char_length(session_tag) > 0),
    CONSTRAINT operator_nonempty    CHECK (char_length(operator) > 0)
);
CREATE INDEX IF NOT EXISTS idx_sessions_tag       ON investigation_sessions (session_tag);
CREATE INDEX IF NOT EXISTS idx_sessions_started   ON investigation_sessions (started_at DESC);

-- One row per invocation of a tool (SpiderFoot scan, theHarvester run, …).
CREATE TABLE IF NOT EXISTS tool_invocations (
    invocation_id   BIGSERIAL PRIMARY KEY,
    session_id      BIGINT NOT NULL REFERENCES investigation_sessions(session_id) ON DELETE CASCADE,
    tool            TEXT   NOT NULL,          -- "spiderfoot" | "harvester" | …
    tool_version    TEXT,
    target          TEXT   NOT NULL,
    arguments       JSONB  NOT NULL DEFAULT '{}'::jsonb,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at        TIMESTAMPTZ,
    exit_status     INTEGER,
    CONSTRAINT tool_nonempty   CHECK (char_length(tool)   > 0),
    CONSTRAINT target_nonempty CHECK (char_length(target) > 0)
);
CREATE INDEX IF NOT EXISTS idx_invocations_session ON tool_invocations (session_id);
CREATE INDEX IF NOT EXISTS idx_invocations_tool    ON tool_invocations (tool);
CREATE INDEX IF NOT EXISTS idx_invocations_started ON tool_invocations (started_at DESC);

-- Normalised findings — one row per discovered entity / artefact.
-- Severity uses TLP-ish bands familiar to threat-intel teams.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'finding_severity') THEN
        CREATE TYPE finding_severity AS ENUM ('info', 'low', 'medium', 'high', 'critical');
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS findings (
    finding_id      BIGSERIAL PRIMARY KEY,
    invocation_id   BIGINT NOT NULL REFERENCES tool_invocations(invocation_id) ON DELETE CASCADE,
    entity_type     TEXT   NOT NULL,           -- "email" | "subdomain" | "ip" | …
    entity_value    TEXT   NOT NULL,
    source_module   TEXT,                      -- e.g. "sfp_dnsresolve"
    confidence      SMALLINT,                  -- 0–100
    severity        finding_severity NOT NULL DEFAULT 'info',
    observed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT entity_type_nonempty   CHECK (char_length(entity_type)   > 0),
    CONSTRAINT entity_value_nonempty  CHECK (char_length(entity_value)  > 0),
    CONSTRAINT confidence_range       CHECK (confidence IS NULL OR (confidence BETWEEN 0 AND 100))
);
CREATE INDEX IF NOT EXISTS idx_findings_invocation ON findings (invocation_id);
CREATE INDEX IF NOT EXISTS idx_findings_entity     ON findings (entity_type, entity_value);
CREATE INDEX IF NOT EXISTS idx_findings_severity   ON findings (severity);

-- Raw tool output — kept in a separate table so the normalised
-- findings can stay narrow. JSONB so we can query into it later
-- without redesigning the schema.
CREATE TABLE IF NOT EXISTS raw_outputs (
    raw_id          BIGSERIAL PRIMARY KEY,
    invocation_id   BIGINT NOT NULL REFERENCES tool_invocations(invocation_id) ON DELETE CASCADE,
    format          TEXT   NOT NULL,           -- "json" | "csv" | "txt" | …
    payload         JSONB  NOT NULL,
    captured_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT format_nonempty CHECK (char_length(format) > 0)
);
CREATE INDEX IF NOT EXISTS idx_raw_invocation ON raw_outputs (invocation_id);

-- Convenience view: latest open session, if any.
CREATE OR REPLACE VIEW current_session AS
SELECT *
  FROM investigation_sessions
 WHERE ended_at IS NULL
 ORDER BY started_at DESC
 LIMIT 1;

COMMIT;

-- ─────────────────────────────────────────────────────────────────
-- Sanity log line so `docker logs postgres` shows the schema loaded.
-- ─────────────────────────────────────────────────────────────────
DO $$
BEGIN
    RAISE NOTICE 'docker-osint-stack audit-log schema initialised';
END
$$;
