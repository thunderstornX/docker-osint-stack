# Workflow: Domain Reconnaissance

A passive-first domain reconnaissance workflow that exercises SpiderFoot
and theHarvester in the stack and writes findings into the audit log.

> **Before you start:** Confirm authorisation. Domain reconnaissance is
> normally low-risk, but **DNS brute-forcing, port-scanning, and active
> crawling are not enabled by default** and must not be turned on
> outside an authorised engagement.

## Phase 0 — scope and legal gate

| Item | Value |
| --- | --- |
| Target domain | `acme.example` *(fill in your authorised target)* |
| Engagement ID | `ACME-2026Q2-042`  *(matches the ticket in your tracker)* |
| Authorisation reference | Written engagement letter §3.1 |
| Scope summary | Public-facing assets of the registered domain only |
| Sensitive data policy | EU residents incidentally surfaced → minimise + delete on engagement close |
| Hard limit | No port scans, no DNS brute, no crawl outside `*.acme.example` |

Record the row in `investigation_sessions` before running any tool:

```sql
INSERT INTO investigation_sessions
  (session_tag, operator, authorisation, scope_summary)
VALUES
  ('ACME-2026Q2-042', 'analyst.handle', 'engagement-letter §3.1',
   'Passive recon of acme.example public-facing assets');
```

## Phase 1 — Priority Intelligence Requirements (PIRs)

| PIR  | Question                                                | Acceptance signal |
| ---  | ------------------------------------------------------- | ----------------- |
| PIR1 | What subdomains are publicly resolvable?                | ≥ N subdomains in DNS sources, cross-referenced ≥ 2 providers |
| PIR2 | Which mail exchangers, name servers, and ASes are used? | MX + NS + ASN inventory complete |
| PIR3 | What technology stack is exposed in HTTP banners?       | Web framework, server fingerprint, JS libraries |
| PIR4 | Does the WHOIS / RDAP record reveal anything actionable?| Registrar, abuse contact, registration date |

## Phase 2 — theHarvester (subdomain + email enumeration)

```bash
# Open a session and capture the invocation in the audit log.
docker compose --profile oneshot run --rm harvester \
    -d acme.example \
    -b bing,crtsh,duckduckgo,otx,rapiddns,urlscan,yahoo \
    -l 500 \
    -f /home/harvester/out/acme-harvest
```

theHarvester exits with a non-zero status if every source fails; keep the
return value so the `tool_invocations` row records it accurately.

## Phase 3 — SpiderFoot (open-source aggregator)

1. Browse to <http://127.0.0.1:8080/> (the Nginx front door).
2. **New Scan** → name `acme-domain-recon-2026Q2`, type `passive`.
3. Modules to enable (passive, low traffic):
   - `sfp_dnsresolve`, `sfp_dnsraw`
   - `sfp_crt`, `sfp_threatcrowd`, `sfp_otx`, `sfp_virustotal_api`
   - `sfp_whois`, `sfp_arin`, `sfp_ripencc`
   - `sfp_httpheader`, `sfp_robotstxt`, `sfp_sitemap`
4. **Disable**: `sfp_dnsbrute`, `sfp_spider`, `sfp_portscan`,
   `sfp_subdomain_takeover_check` (active probing).

When the scan completes, export results as CSV via the SpiderFoot UI
and feed them into the audit log:

```sql
INSERT INTO tool_invocations
  (session_id, tool, tool_version, target, arguments)
VALUES
  ((SELECT session_id FROM current_session),
   'spiderfoot', '4.0', 'acme.example',
   '{"modules": ["sfp_dnsresolve", "sfp_crt", "sfp_whois"]}'::jsonb)
RETURNING invocation_id;
```

## Phase 4 — Triage

| Severity   | What goes here |
| ---------- | --- |
| `critical` | Exposed admin panel, default-creds banner, leaked private key |
| `high`     | Subdomain takeover candidate, exposed `.git`, exposed `.env` |
| `medium`   | Stale subdomain, expired cert with sensitive CN |
| `low`      | Outdated server banner, missing security headers |
| `info`     | Standard inventory rows (MX, NS, registrar) |

Findings land in the `findings` table linked to the invocation; raw
exports land in `raw_outputs`.

## Phase 5 — Close

1. Mark the session ended:
   `UPDATE investigation_sessions SET ended_at = NOW() WHERE session_id = …;`
2. Export the audit log: `bash scripts/export_findings.sh`
3. Tear down the stack: `bash scripts/teardown.sh --shred`

The encrypted dump under `exports/` is the only durable artefact.
