# Workflow: <name>

Blank template. Copy this file to a new name under `workflows/` and
fill in. The structure is intentionally rigid: every phase is a gate,
not a suggestion.

## Phase 0 — scope and legal gate

| Item | Value |
| --- | --- |
| Target | *(domain / org / asset)* |
| Engagement ID | *(matches tracker ticket)* |
| Authorisation reference | *(letter §, ethics approval, court order…)* |
| Scope summary | *(one sentence)* |
| **Out of scope** | *(named exclusions — be specific)* |
| Sensitive data policy | *(retention + destruction)* |
| Hard limits | *(active probes? port scans? DNS brute?)* |

Open the session row before doing anything else:

```sql
INSERT INTO investigation_sessions
  (session_tag, operator, authorisation, scope_summary)
VALUES
  ('<TAG>', '<operator.handle>', '<authorisation ref>',
   '<scope summary>');
```

## Phase 1 — Priority Intelligence Requirements

| PIR  | Question | Acceptance signal |
| ---  | -------- | ----------------- |
| PIR1 |          |                   |
| PIR2 |          |                   |
| PIR3 |          |                   |

Each PIR must have a *binary* acceptance signal. "Got some data" is
not an acceptance signal.

## Phase 2 — theHarvester (if relevant)

```bash
docker compose --profile oneshot run --rm harvester \
    -d <target> \
    -b <comma,separated,sources> \
    -l <limit> \
    -f /home/harvester/out/<filename>
```

If theHarvester is not relevant to this workflow, delete this phase.
Do not run tools out of habit.

## Phase 3 — SpiderFoot

Modules enabled:

- `sfp_…`

Modules **explicitly disabled** (any active probing):

- `sfp_dnsbrute`, `sfp_spider`, `sfp_portscan`, …

## Phase 4 — Triage

| Severity   | Definition for *this* workflow |
| ---------- | ------------------------------ |
| `critical` |  |
| `high`     |  |
| `medium`   |  |
| `low`      |  |
| `info`     |  |

Define severity per workflow. A `high` here is not the same as a
`high` in a different workflow. Make the bar explicit.

## Phase 5 — Close

1. `UPDATE investigation_sessions SET ended_at = NOW() WHERE session_id = …;`
2. `bash scripts/export_findings.sh`
3. `bash scripts/teardown.sh --shred`  *(or `--keep-volumes` if the
   engagement continues across sessions)*

## Phase 6 — Lessons learned

After every engagement, log:

- What worked.
- What surfaced false positives.
- Which modules / sources to retire next time.

This is the only phase the audit log cannot capture automatically.
Write it by hand into the engagement notes.
