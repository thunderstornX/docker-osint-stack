# Results — measured, reproducible

Every file in this directory is the literal output of a tool run against
the artefacts in this repository on the date stamped in
`scan_summary.json` / `runtime_summary.json`. **No numbers in the
top-level README are invented.** If a number is in the README, the
provenance is here.

## Files

| File | Provenance |
| --- | --- |
| `hadolint.txt` | `~/.local/bin/hadolint services/spiderfoot/Dockerfile services/harvester/Dockerfile` |
| `trivy_<image>.json` | `trivy image --format json -o ... <image>`, one per image |
| `dockle_<image>.json` | `dockle --exit-code 0 --format json -o ... <image>`, **un-filtered** |
| `dockle_<image>_filtered.json` | Same with documented suppressions (`-af settings.py`, `-ak KEY_SHA512`) |
| `scan_summary.json` | Aggregator over the above, with tool versions and suppression rationale |
| `boot_log.txt` | `/usr/bin/time -f '%e seconds' bash scripts/start.sh` |
| `runtime_stats.txt` | `docker stats --no-stream` captured ~3s after all healthchecks green |
| `runtime_summary.json` | Structured re-encoding of the above with the smoke-test outcomes |
| `test_stack.log` | Verbose log of `bash tests/test_stack.sh` |
| `test_stack_output.txt` | The PASS/FAIL line for each assertion |

## Suppressions documented in `scan_summary.json`

We use two and only two Dockle suppressions, both for verifiable false
positives:

1. **`-af settings.py`** — applied to `dockle_<spiderfoot|harvester>_filtered.json`.
   Both images contain upstream Python library files literally named
   `settings.py` (in `python-docx` and `python-shodan` respectively).
   Dockle's CIS-DI-0010 heuristic flags any file whose name contains
   `setting` as a possible credential store. These files are library
   modules and contain no secrets.

2. **`-ak KEY_SHA512`** — applied to `dockle_nginx_1.27-alpine_filtered.json`.
   The official `nginx:1.27-alpine` Dockerfile sets a `KEY_SHA512`
   variable equal to the SHA-512 checksum of the nginx APK signing
   key. The variable name matches Dockle's CIS-DI-0010 pattern but
   the value is a hash, not a credential.

No other suppressions are in effect. CVE counts from Trivy are
reported as-measured; we do not suppress, ignore, or downgrade CVEs.
