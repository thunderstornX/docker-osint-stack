# Workflow: Credential Exposure Check

A workflow for detecting credentials associated with an authorised
target **domain** that have surfaced in publicly known breaches or
paste sites. The unit of investigation is the **domain**, not the
individual employee.

> **Scope guardrail:** This workflow does not download breach corpora,
> does not attempt credential validation, and does not enumerate
> individual employees beyond what HaveIBeenPwned's domain endpoint
> returns. If you need per-employee triage with named individuals,
> that is a HR / legal conversation, not an OSINT one.

## Phase 0 — scope and legal gate

| Item | Value |
| --- | --- |
| Target domain | `acme.example` |
| Authorisation reference | Engagement letter §3.6 — credential exposure scan |
| Scope summary | Public breach-corpus references to `*@acme.example` only |
| Personal data handling | All addresses kept under encrypted export; named to HR via secure channel only |
| Retention | 30 days, then `teardown.sh --shred` |

## Phase 1 — Priority Intelligence Requirements

| PIR | Question | Acceptance signal |
| --- | --- | --- |
| PIR1 | Which company-domain addresses appear in known breaches? | HIBP `breachedaccount` or `breaches` API rows |
| PIR2 | Has any password reuse been demonstrated (hashed) in pastes? | Paste site references with the domain string |
| PIR3 | Are there exposed credentials in public source code? | GitHub dorks: `"acme.example" filename:.env`, etc. |

## Phase 2 — SpiderFoot modules

In a passive scan:

- `sfp_haveibeenpwned`   — domain → list of breaches affecting addresses
- `sfp_pastebin`          — paste sites mentioning the domain
- `sfp_github`            — public GitHub references
- `sfp_emailrep`          — reputation lookup for surfaced emails

Disable any module that performs login attempts, password reset
probes, or active account validation. Defence in depth:
`spiderfoot.cfg` already disables `sfp_spider`, `sfp_dnsbrute`,
`sfp_portscan`.

## Phase 3 — theHarvester (passive email enumeration)

```bash
docker compose --profile oneshot run --rm harvester \
    -d acme.example \
    -b bing,duckduckgo,yahoo,urlscan,otx \
    -l 500 \
    -f /home/harvester/out/acme-cred
```

This produces the address inventory that the SpiderFoot pass cross-
references against breach corpora. **No password content** is sought
or stored; the artefact is "address X appears in breach Y at date Z".

## Phase 4 — Triage

| Severity | What goes here |
| --- | --- |
| `critical` | Live exec / shared-mailbox address in a recent breach |
| `high` | Privileged-role address (admin, root, devops) in any breach |
| `medium` | Generic address in a recent (≤ 12 mo) breach |
| `low` | Long-stale breach reference |
| `info` | Address present but never breached |

Severity is determined **only** by the role and recency, never by the
employee's identity. The output to HR / legal is a **count plus role
buckets**, not a named list — that decision is for the engagement
manager, not the stack.

## Phase 5 — Close

1. Mark the session ended.
2. `bash scripts/export_findings.sh` (mandatory — credential data
   must not leave the stack in plaintext).
3. `bash scripts/teardown.sh --shred` (mandatory — wipes volumes
   and shreds the plaintext export).

The encrypted `audit-log-*.sql.gpg` under `exports/` is the only
artefact that should leave the host.
