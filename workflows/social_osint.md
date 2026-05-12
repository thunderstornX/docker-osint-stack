# Workflow: Social Media OSINT (organisation-centric)

A workflow for investigating an **organisation's social media footprint**
— corporate accounts, employee professional accounts where lawful in
scope, geofenced public posts.

> **Hard constraint:** This stack is organisation-centric. Investigating
> private individuals through their social media is **out of scope**
> here. If your engagement requires that, you need a separate ethical
> review and you should not be using this workflow as cover.

## Phase 0 — scope and legal gate

| Item | Value |
| --- | --- |
| Target organisation | `Acme Corp` *(fill in your authorised target)* |
| Authorisation reference | Engagement letter §3.4 — social presence audit |
| Scope summary | Public-facing official accounts + employee accounts that voluntarily list the employer |
| **Out of scope** | DMs, friends-only posts, OSINT pivots to private individuals |
| Retention | Findings retained 90 days post-engagement, then `teardown.sh --shred` |

Authorisation must explicitly say "social media review" — generic
"reconnaissance" is not enough cover for this workflow.

## Phase 1 — Priority Intelligence Requirements (PIRs)

| PIR  | Question                                                       | Acceptance signal |
| ---  | -------------------------------------------------------------- | ----------------- |
| PIR1 | What official accounts does the org operate?                   | LinkedIn page, X, GitHub org, YouTube channel inventoried |
| PIR2 | What public information leaks about internal projects?         | Job ads naming tooling, GitHub repos exposing pipelines |
| PIR3 | Are there impersonator / typosquat accounts?                   | Similar handles across the same platforms |
| PIR4 | Is there a credible insider threat surface in public posts?    | Disgruntled-employee posts, doxxed internal screenshots |

## Phase 2 — theHarvester (search-engine sweep)

```bash
docker compose --profile oneshot run --rm harvester \
    -d "acme corp" \
    -b duckduckgo,yahoo,linkedin_links \
    -l 200 \
    -f /home/harvester/out/acme-social
```

The `linkedin_links` source returns *public* profile URLs only; do not
attempt to scrape connection lists, follower graphs, or DMs.

## Phase 3 — SpiderFoot (social and code-paste modules)

In the UI, run a passive scan with these modules:

- `sfp_linkedin`         — public company-page references
- `sfp_github`            — public org repos and contributors
- `sfp_pastebin`          — paste sites that mention the domain
- `sfp_haveibeenpwned`    — breached employee emails (the domain, not
  named individuals)
- `sfp_subdomain_neighbours` — adjacent properties under shared ASN

Explicitly **disabled** in `spiderfoot.cfg` (defence in depth):

- `sfp_phone` against individual numbers
- Any module that posts data or creates accounts on third-party sites

## Phase 4 — Triage and review

| Severity | What goes here |
| --- | --- |
| `high` | Verified credential exposure, exposed internal screenshots |
| `medium` | Plausible impersonator account, leaked job-ad detail |
| `low` | Stale official account, weak handle hygiene |
| `info` | Inventory rows for legitimate accounts |

Every employee personal account that comes up should be tagged
`info` and never escalated to `medium+` unless the post is overtly
work-related (e.g. exposing customer data). Personal grievance posts
are **not** in scope and should be dropped from findings.

## Phase 5 — Close

1. Mark the session ended.
2. `bash scripts/export_findings.sh`
3. `bash scripts/teardown.sh --shred`

For social workflows specifically, the 90-day retention should be
shorter than the engagement letter's hard limit — over-retention of
incidental personal data is the most common compliance failure mode.
