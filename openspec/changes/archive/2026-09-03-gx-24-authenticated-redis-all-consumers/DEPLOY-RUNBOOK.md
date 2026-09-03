# GX-24 authenticated Redis: deploy-verification runbook

Verify the authenticated-Redis change in three credential modes across every Redis consumer. This
pass delivers the runbook; running it against a live cluster is a separate deploy step (design D1).

All three modes render from the same chart. Nothing new renders until a credential is set, so
Mode A proves the change is safe for every existing install.

## Consumers covered

- cashbot-go session client (`config.yaml` `rec.session` + `metrics.session`) — reads username/password.
- ai-server: `status.py` direct client (parses the credentialed URL) + the layout/summary/ranker/document Celery brokers (kombu, credentialed URL).
- internal-arcadia-agents (extract): Celery broker + metrics broker (kombu, credentialed URL).
- groundx-workspace-runner: Celery broker + result backend (kombu, credentialed URL).
- The chart-created (in-cluster) `cache` and `cache.metrics` Redis servers themselves, when a credential is set.

## Redis target: external/managed vs chart-created

- **External/managed Redis** (`cache.existing.addr` set): the operator runs the authenticated server; the chart only renders the credential into each consumer's config/URL. TLS is per-identity (`cache.existing.ssl`, `cache.metrics.existing.ssl`, `ranker.cache.ssl`).
- **Chart-created Redis** (no `existing.addr`): the chart configures the in-cluster `cache`/`cache.metrics` StatefulSet to require the same credential (a mounted `redis.conf` Secret; the pod launches `redis-server` with it). Verified against the shipped image `eyelevel/redis:1.0.0`.

## Mode A: credential-less (backward compatibility)

Values: no `cache.password`/`cache.username` (default).

1. `helm template groundx src/groundx` renders identically to 0.2.7 (byte-identical; verified in CI via the golden snapshots and a direct render-diff).
2. No `cache-conf`/`cache-metrics-conf` Secret is rendered; the `cache`/`cache-metrics` StatefulSets carry no `args`, conf volume/mount, or `config-hash` annotation.
3. Deploy (or `helm upgrade`) an existing install: every Redis consumer connects exactly as before; no `NOAUTH`/`AUTH` errors in cashbot-go, ai-server, arcadia, or workspace-runner logs.

## Mode B: password-only (AUTH `requirepass`)

Values: `cache.password: <pw>` (leave `cache.username` unset). For a chart-created Redis this also configures the server; for an external Redis, set the same `requirepass` on that server.

1. Rendered URLs carry `scheme://:<pw>@host:port/0` (colon prefix — the password is in the password position, not the username position). Reserved characters are percent-encoded; a space renders as `%20`.
2. Rendered `config.yaml` `rec.session`/`metrics.session` carry `password: "<pw>"` and no `username`.
3. Chart-created server: the `cache-conf` Secret's `redis.conf` contains `include /etc/redis.conf` then `requirepass "<pw>"`; the StatefulSet launches `redis-server <mounted>/redis.conf`.
4. Deploy: the cache pod reaches Ready; cashbot-go, ai-server (status + Celery), arcadia, and workspace-runner all authenticate. Confirm a client with the wrong password is rejected.

## Mode C: username + password (ACL user)

Values: `cache.username: <user>` and `cache.password: <pw>`. The username must be a bare token (no whitespace — the schema rejects whitespace with a clear error). For an external Redis, create the matching ACL user on that server.

1. Rendered URLs carry `scheme://<user>:<pw>@host:port/0`, percent-encoded.
2. Rendered `config.yaml` session blocks carry both `username: "<user>"` and `password: "<pw>"`.
3. Chart-created server: the `redis.conf` contains `include /etc/redis.conf`, then `user default off` and `user <user> on ">pw" ~* &* +@all`.
4. Deploy: every consumer authenticates as the ACL user. cashbot-go picks up the ACL user only with its `Username` field change (shipped in the cashbot-go PR); an old cashbot-go image ignores the ACL username (password-only still works).

## Per-identity notes

- **metrics cache**: set `cache.metrics.username`/`password` (and `cache.metrics.existing.addr`/`ssl` for a separate external instance) only when metrics runs on its own Redis; otherwise it inherits the main cache credential and scheme. A separately hosted TLS metrics Redis renders `rediss://`.
- **ranker cache**: set `ranker.cache.username`/`password` (+ `ranker.cache.addr`/`ssl`) only for a ranker-only Redis; otherwise it inherits the main cache credential.
- **workspace**: an operator-supplied full `workspace.celeryBrokerUrl`/`celeryResultBackend` is never rewritten; only a defaulted (main-cache-derived) URL receives the credential, each independently.

## Credential rotation

Changing a credential changes the `config-hash` annotation on every affected Deployment/StatefulSet, forcing a rolling restart so the new credential takes effect.
