## Context

Celery worker programs are named `<pod>-w<n>` with `--concurrency=<threads>` in each service's supervisord config, using the `workers` and `threads` of that service's settings. Layout's process records are `layout-inference:<pod>-w<n>-p<i>:{status,total,requests}`.

## Decision

- The shared inference template renders the two annotations from the service settings' `workers` and `threads`. Layout's supervisord config reads the same settings, so the annotation and the started concurrency come from one value. Ranker and summary settings gain `workers` and `threads` from their existing helpers so every inference pod publishes its counts.
- Layout `config.py` renders `threads` from `groundx.layout.inference.threads`, beside the existing `workers`.
- cashbot-go switches a metric to exact reads only through `exactKeys`, set for layout-inference alone. Annotation presence does not switch it, because summary-api and summary-client records are not named after pods, and ranker uses the busy-window path.

## Consequences

- Readers that know a pod's counts need no Redis scan for its capacity records.
- The first deploy of this chart version rolls inference pods once, because their pod template changes.
- A pod started by an older chart has no annotations; cashbot-go then keeps scanning for that service until every pod is replaced.
