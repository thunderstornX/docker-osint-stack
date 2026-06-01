<!-- markdownlint-disable MD033 MD041 -->

```
 ╔═════════════════════════════════════════════════════════════════╗
 ║   d o c k e r - o s i n t - s t a c k                          ║
 ║                                                                 ║
 ║   one command up · audit-logged · encrypted export · honest     ║
 ║   scans · no fabricated numbers                                 ║
 ╚═════════════════════════════════════════════════════════════════╝
```

> 🛑 **Read [ETHICAL_USE.md](ETHICAL_USE.md) before running this stack.**
> Organisation-centric scope. Doxxing, stalking, and personal-target
> investigations are explicitly out of scope.

[![hadolint](https://img.shields.io/badge/hadolint-0%20findings-brightgreen)](results/hadolint.txt)
[![dockle](https://img.shields.io/badge/dockle-0%20FATAL%20(filtered)-brightgreen)](results/scan_summary.json)
[![smoke tests](https://img.shields.io/badge/smoke%20tests-10%2F10%20PASS-brightgreen)](results/runtime_summary.json)
[![boot time](https://img.shields.io/badge/boot%20to%20healthy-7.5s-brightgreen)](results/runtime_summary.json)
[![idle RAM](https://img.shields.io/badge/idle%20RAM-153%20MiB-blue)](results/runtime_summary.json)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.20480469.svg)](https://doi.org/10.5281/zenodo.20480469)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

A reproducible Docker Compose stack that bundles **SpiderFoot v4.0**,
**theHarvester 4.10.1**, **PostgreSQL 16**, and **Nginx 1.27** into a
single-command OSINT collection environment with an opinionated
**audit-log schema**, three **operational scripts** (start /
teardown / GPG-encrypted export), four **investigation workflow
templates**, and **real DevSecOps gates** (hadolint, Trivy, Dockle).
All measurements in this README come from `results/` and are
reproducible by re-running the scripts.

## Architecture

```
   ┌─────────────────────────────────────────────────────────────┐
   │  Host (Linux + Docker 29.x + Compose v2)                    │
   │                                                             │
   │   127.0.0.1:8080  ────────► ┌──────────────────────┐        │
   │   (operator browser)        │  nginx:1.27-alpine   │        │
   │                             │  (only exposed surf) │        │
   │                             └──────────┬───────────┘        │
   │                                        │                    │
   │                       reverse proxy ↓ (HTTP, intra-net)     │
   │                                        │                    │
   │  ┌─────────────────────────────────────┴───────────────┐    │
   │  │  SpiderFoot v4.0  (passive recon, web UI on :5001) │    │
   │  └─────────────────────┬───────────────────────────────┘    │
   │                        │                                    │
   │                        │  audit-log inserts                 │
   │                        ▼                                    │
   │           ┌────────────────────────────┐                    │
   │           │  postgres:16-alpine        │                    │
   │           │  investigation_sessions    │                    │
   │           │  tool_invocations          │                    │
   │           │  findings                  │                    │
   │           │  raw_outputs (jsonb)       │                    │
   │           └────────────────────────────┘                    │
   │                                                             │
   │   one-shot (via `docker compose --profile oneshot run`):    │
   │   ┌─────────────────────────────────────────┐               │
   │   │  theHarvester 4.10.1                    │               │
   │   │  (subdomain + email enumeration CLI)    │               │
   │   └─────────────────────────────────────────┘               │
   │                                                             │
   │   stack-net (bridge, internal only)                         │
   └─────────────────────────────────────────────────────────────┘
                                  │
                                  │  scripts/export_findings.sh
                                  ▼
                          ./exports/audit-log-<ts>.sql.gpg
                          (GPG AES-256 symmetric)
```

**Design constraints honoured in the layout:**

- The host port (default `127.0.0.1:8080`) is the **only** externally
  reachable surface. SpiderFoot, Postgres, and theHarvester each
  publish no host ports.
- Every long-running container declares a **HEALTHCHECK**;
  `scripts/start.sh` polls them with a 3-minute deadline and fails
  loudly if anything stays unhealthy.
- The audit-log is a separate Postgres service, not a SQLite file
  inside the SpiderFoot container, so destroying the SpiderFoot
  volume does not destroy the engagement record.
- `theHarvester` is bound to `profiles: ["oneshot"]` so it does not
  start on `docker compose up` — it runs deliberately, per
  workflow, via `docker compose --profile oneshot run --rm harvester …`.

## Quick start

```bash
git clone https://github.com/thunderstornX/docker-osint-stack.git
cd docker-osint-stack

# 1. Configure
cp config/.env.example config/.env
$EDITOR config/.env                # set POSTGRES_PASSWORD, EXPORT_GPG_PASSPHRASE

# 2. Boot — the script polls every HEALTHCHECK and fails fast if any
#    service does not go green within 3 minutes.
bash scripts/start.sh

# 3. Open the UI
xdg-open http://127.0.0.1:8080/    # or your browser of choice

# 4. Run theHarvester one-shot (does NOT run as a daemon)
docker compose --env-file config/.env --profile oneshot run --rm harvester \
    -d acme.example -b bing,duckduckgo,crtsh -l 200 \
    -f /home/harvester/out/acme

# 5. Export the audit log, encrypted
bash scripts/export_findings.sh    # writes exports/audit-log-<ts>.sql.gpg

# 6. Tear down (default: removes containers + named volumes)
bash scripts/teardown.sh --shred   # also GNU-shreds any exports/ artefacts
```

## Workflows

Four investigation templates live under `workflows/`. Each follows the
same six-phase structure: scope-and-legal gate → Priority Intelligence
Requirements → theHarvester pass → SpiderFoot pass → triage table →
session close. The legal-gate phase is **mandatory** and must point at
a real authorisation record before any tool runs.

| Workflow | Use case |
| --- | --- |
| [`domain_recon.md`](workflows/domain_recon.md) | Passive-first reconnaissance of an authorised target domain. |
| [`social_osint.md`](workflows/social_osint.md) | Organisation-centric social media footprint review. |
| [`cred_exposure.md`](workflows/cred_exposure.md) | Public breach-corpus references for `*@target` addresses. |
| [`workflow_template.md`](workflows/workflow_template.md) | Blank template — copy when adding a new investigation type. |

## Audit-log schema

`services/audit-log/init.sql` is loaded automatically by Postgres on
first boot. It defines four tables linked by foreign keys:

| Table | Purpose |
| --- | --- |
| `investigation_sessions` | One row per engagement / question. Carries the operator name and **authorisation reference**. |
| `tool_invocations` | One row per SpiderFoot scan or theHarvester run, with arguments as JSONB. |
| `findings` | Normalised, severity-bucketed entities (`info` → `critical`). |
| `raw_outputs` | Verbatim tool output as JSONB, FK'd to the invocation. |

Plus a `finding_severity` ENUM, a `current_session` view, and
constraint-level checks so the schema refuses to record an empty
session tag, operator, or authorisation reference.

## DevSecOps posture — *measured*, not claimed

All numbers below come from `results/scan_summary.json` and
`results/runtime_summary.json`. Re-run any scan to regenerate.

### Dockerfile lint (hadolint v2.12.0)

| Dockerfile | Findings |
| --- | --- |
| `services/spiderfoot/Dockerfile` | **0** |
| `services/harvester/Dockerfile`  | **0** |

### CVE scan (Trivy v0.70.0)

Real, honest counts. Numbers are non-zero because SpiderFoot v4.0
(April 2022) pins dependencies that have accreted CVEs since release;
we do not silently suppress them.

| Image | Size (content) | CRITICAL | HIGH | MEDIUM | LOW |
| --- | ---: | ---: | ---: | ---: | ---: |
| `docker-osint-stack/spiderfoot:v4.0`    | 339 MB | 8 | 46 | 120 | 118 |
| `docker-osint-stack/harvester:4.10.1`   | 352 MB | 3 | 17 |  72 |  94 |
| `postgres:16-alpine`                    | 263 MB | 1 | 13 |  19 |   1 |
| `nginx:1.27-alpine`                     |  46 MB | 6 | 29 |  46 |   9 |

**Remediation posture** (transparent about what we do and do not
fix):

- For the **custom images**, we accept SpiderFoot's pinned dependency
  tree because forcibly upgrading risks breaking SpiderFoot's own
  imports. The patch path is "wait for upstream to ship v4.1+"; we
  pin to a *tag*, not a commit, so a rebuild picks up upstream
  fixes automatically when they ship.
- For the **base images** (`postgres:16-alpine`, `nginx:1.27-alpine`,
  `python:3.12-slim-bookworm`, `python:3.9-slim-bookworm`), we pin both
  the human-readable tag and an immutable `@sha256:` digest in the
  Compose file and Dockerfiles, so a rebuild resolves byte-for-byte to
  the same base layers. To adopt an upstream patch release, re-pin the
  digest deliberately. The numbers above are correct as of `as_of_utc`
  in `results/scan_summary.json`.

### Container best-practice (Dockle v0.4.15)

After two documented false-positive suppressions:

| Image | FATAL | WARN |
| --- | ---: | ---: |
| `docker-osint-stack/spiderfoot:v4.0`    | 0 | 0 |
| `docker-osint-stack/harvester:4.10.1`   | 0 | 0 |
| `postgres:16-alpine`                    | 0 | 1 |
| `nginx:1.27-alpine`                     | 0 | 1 |

The two suppressed findings are:

1. **`-af settings.py`** — `python-docx` and `python-shodan` both ship
   a library file named `settings.py`. Dockle's heuristic flags any
   such filename as a possible credential store; neither file contains
   credentials.
2. **`-ak KEY_SHA512`** — the official `nginx:1.27-alpine` Dockerfile
   sets `KEY_SHA512` to the SHA-512 of nginx's APK signing key. The
   variable name matches Dockle's pattern; the value is a hash, not a
   credential.

The remaining WARN on `postgres` and `nginx` is "Last user should not
be root" — true at image-layer level for these official images, but
defence-in-depth-covered by:
- `no-new-privileges:true` in every service block of `docker-compose.yml`,
- Nginx's worker processes run as the `nginx` user inside the
  container,
- Postgres's main process runs as the `postgres` user inside the
  container.

We chose to keep the WARN visible rather than rebase the images on
custom Dockerfiles just to flip a bit.

### Live boot — wall clock

```text
$ /usr/bin/time -f '%e seconds' bash scripts/start.sh
…
[start] waiting for dos-postgres: ..healthy
[start] waiting for dos-spiderfoot: healthy
[start] waiting for dos-nginx: healthy
[start] all services healthy.
7.48 seconds
```

### Idle resource use (`docker stats --no-stream`)

| Container | RAM | CPU |
| --- | ---: | ---: |
| `dos-postgres`    |  36.9 MiB | 0.02 % |
| `dos-spiderfoot`  | 106.2 MiB | 0.08 % |
| `dos-nginx`       |  10.2 MiB | 0.00 % |
| **Total**         | **153.2 MiB** | — |

theHarvester does not appear in the idle table because it is a
one-shot tool (it exits between runs).

### Smoke test (`tests/test_stack.sh`)

```text
[test] 10 pass, 0 fail
```

The ten assertions exercise: compose syntax, env presence, full stack
boot, Postgres readiness, SpiderFoot HTTP, Nginx `/healthz`, the Nginx
→ SpiderFoot proxy path, audit-log schema presence, an end-to-end
CTE round-trip through `investigation_sessions →
tool_invocations → findings`, and a one-shot theHarvester invocation.

## Security model — what this stack does and does not protect

**What the stack does protect:**

- **Confidentiality of exports** via GPG AES-256 symmetric on
  `pg_dump` output, with the plaintext shredded immediately
  afterwards.
- **Confidentiality of the host network** via default `127.0.0.1`
  binding on the Nginx port and no host-port publication on any other
  service.
- **Reproducibility** via pinned upstream tags / image digests and
  hadolint-clean Dockerfiles.
- **Audit trail** via a Postgres schema that captures who did what,
  when, with which authorisation, and against which target.

**What the stack does *not* protect:**

- **TLS at the edge.** The Nginx config terminates plain HTTP on
  `127.0.0.1`. Do not expose this to anything but localhost without
  putting a TLS-terminating reverse proxy (Caddy, Traefik, …) and
  basic-auth in front.
- **Per-user authentication.** SpiderFoot's UI is single-tenant; the
  stack assumes one trusted operator per host.
- **Defence against a compromised SpiderFoot upstream.** We pin to a
  tag, not a commit, so a rebuild trusts whatever upstream has
  retroactively put behind that tag. Mitigate by verifying the
  `v4.0` commit hash before rebuild in regulated environments.

## File layout

```
docker-osint-stack/
├── docker-compose.yml          # Compose v3.8 schema, hardening anchor
├── services/
│   ├── spiderfoot/
│   │   ├── Dockerfile          # multi-stage, non-root, healthchecked
│   │   └── spiderfoot.cfg      # passive-by-default config notes
│   ├── harvester/
│   │   └── Dockerfile          # built from upstream git at tag 4.10.1
│   └── audit-log/
│       └── init.sql            # 4 tables + ENUM + view + CHECK constraints
├── workflows/                  # 4 investigation templates
├── scripts/                    # start.sh, teardown.sh, export_findings.sh
├── config/
│   ├── .env.example
│   └── nginx.conf              # reverse-proxy in front of SpiderFoot
├── tests/
│   └── test_stack.sh           # 10-assertion smoke test
├── paper/                      # companion IEEE writeup (paper.tex)
└── results/                    # measured outputs: hadolint, trivy, dockle, runtime
```

## What this README does *not* claim

- It does **not** claim zero CVEs. The measured numbers are above.
- It does **not** claim full GDPR / CFAA / PECA compliance — that's
  per-engagement legal work. The companion repo
  [`osint-methodology-vault`](https://github.com/thunderstornX/osint-methodology-vault)
  carries the legal templates.
- It does **not** claim novel OSINT capability. The stack composes
  publicly available tools (SpiderFoot, theHarvester) with an
  opinionated audit-log and DevSecOps layer.
- It does **not** measure detection or recall on real targets. No
  benchmark numbers because there is no benchmark — the contribution
  is reproducible packaging, not new detection.

## Companion paper

A short IEEE writeup of the architecture pattern lives at
[`paper/paper.tex`](paper/paper.tex) → `paper/paper.pdf`. It cites
Bazzell's *Open Source Intelligence Techniques*, NIST SP 800-190
(*Application Container Security Guide*), Heuer's *Psychology of
Intelligence Analysis*, the CIS Docker Benchmark, and the
PostgreSQL Documentation — no self-citations.

## Citing

If you use this stack in academic or professional work, please cite
the [`CITATION.cff`](CITATION.cff) record. The Zenodo metadata is in
[`.zenodo.json`](.zenodo.json).

## License

MIT. See [LICENSE](LICENSE). The MIT licence governs the glue
(Dockerfiles, compose config, scripts, workflows, docs); the upstream
projects (SpiderFoot, theHarvester, Postgres, Nginx) carry their own
licences.
