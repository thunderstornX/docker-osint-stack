# Ethical Use Policy

`docker-osint-stack` is a **defensive and authorised-engagement** tool. It
bundles publicly available OSINT software (SpiderFoot, theHarvester) into a
single launchable environment for security teams, threat intel analysts,
and academic researchers. The packaging adds no novel offensive capability;
it makes the existing tools easier to deploy reproducibly and to audit
afterwards.

## Scope — what this stack is *for*

- Authorised security assessments of an organisation you have written
  permission to assess.
- Defensive threat-intelligence collection about your own assets, your
  own employer, or your own infrastructure.
- Academic research on OSINT methodology where the targets are public
  organisations or synthetic, fictional entities.
- Capture-the-flag and training environments.

## Out of scope — what this stack must **not** be used for

- **Person-centric investigation**, doxxing, stalking, or harassment.
  SpiderFoot's email and username modules can enumerate individuals; do
  not point them at private individuals you have no authorised reason
  to investigate.
- Investigating minors under any circumstance.
- Pre-litigation discovery of opposing private parties without a clear
  legal authorisation chain.
- Domestic-abuse, intimate-partner, or workplace-grudge investigations
  ("am I being cheated on", "is my coworker doing X", etc.).
- Any collection that violates the target's local data protection law,
  the operator's local computer-misuse law, or the GDPR if EU personal
  data is incidentally processed.

## "Publicly accessible" is not a free pass

Even when data is technically reachable without authentication, the
collection may still be unlawful or unethical. Before running this stack
you should be able to answer **yes** to all four:

1. Is there a **lawful basis** for the collection (Article 6 GDPR if EU
   data is involved, a written engagement letter, or a documented
   academic ethics approval)?
2. Is the collection **proportionate** to the question being asked?
3. Is the collection **logged** so the same audit trail you would expect
   from a regulated activity exists here (the `audit-log` Postgres
   service is exactly that)?
4. Is there a **destruction date** after which the artefacts are wiped?
   `teardown.sh --shred` is provided for that. The default retention is
   "until the engagement closes."

If you cannot answer yes to all four, do not run the stack.

## Operator commitments

By running this stack the operator commits to:

- Read and comply with the legal phase of the companion repository
  [`osint-methodology-vault`](https://github.com/thunderstornX/osint-methodology-vault),
  in particular the 12-jurisdiction compliance matrix and the GDPR
  Article-by-Article checklist.
- Not use SpiderFoot's intrusive modules (port scanning, DNS brute
  force, etc.) outside an authorised engagement.
- Treat any incidental personal data with the same care a regulated
  entity would: minimisation, retention limits, encrypted export
  (`export_findings.sh` uses GPG symmetric for exactly this reason),
  and verified destruction at end of engagement.

## Attribution

This stack depends on and gratefully credits:

- **SpiderFoot** by Steve Micallef — https://github.com/smicallef/spiderfoot — GPLv2
- **theHarvester** by Christian Martorella — https://github.com/laramies/theHarvester — GPLv2
- **PostgreSQL** — https://www.postgresql.org/ — PostgreSQL License
- **Nginx** — https://nginx.org/ — BSD-2-Clause

Their licences govern their own source. This repository's MIT licence
governs only the glue — Dockerfiles, compose configuration, workflow
templates, scripts, and documentation.
