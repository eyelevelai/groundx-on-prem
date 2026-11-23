# Celery worker render identity

A render comparison was run at change time on each base. It rendered the base and the branch for 8 value combinations: default, all enabled (extract and workspace on), `replicas.gracePeriod` on every worker family, cache valkey, chainguard, 2 workers per family, 3 workers per family, and `mode: ingest`. It then compared every Celery worker Deployment and `*-supervisord-conf-map` ConfigMap byte for byte, and the `helm/` render with the `src/groundx` render. The only difference it allowed was the extract `[group:celery_workers]` section, which must list exactly `celery_worker_1..N`, and the extract Deployments' `supervisord-hash` line. It failed if any of the 16 Celery services was not rendered by some combination.

| Case | Expected | Actual | Pass/Fail |
|---|---|---|---|
| Branch `a6a35465` vs merge-base `76615060` (2026-11-02) | identical except the extract group | identity holds for all 8 combinations | PASS |
| Branch `da2fd346` vs `0.3.0` at `87027773` (2026-11-03) | identical except the extract group | "celery render identity holds against origin/0.3.0 for 8 value combinations" | PASS |

The comparison script is not committed. After merge, the committed snapshots fail on any change to a Supervisor config or its hash, and `verify_mirrors()` in `.build/bin/verify-storage-contract.py` compares the two template trees on every gate run.
