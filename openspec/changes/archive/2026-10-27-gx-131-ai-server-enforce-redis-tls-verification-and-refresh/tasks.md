## 1. The note: behavior change and who is unaffected (first shippable slice)

- [x] 1.1 Add the "Upgrading to Chart 0.2.8 with a `rediss://` Redis" `####` note to `README.md` inside "Using an Existing Redis Cluster", before "Deploying a Dedicated Redis Cluster", stating that chart 0.2.8 images verify chain and host name for `rediss://` in the ai-server layout, ranker and summary services (APIs and workers) when `ssl: true` is set under `cache.existing` or `ranker.cache`, and that the certificate must cover the `addr` of each.
  check: bash -c 's=$(sed -n "/^#### Upgrading to Chart 0.2.8 with a /,/^#### Deploying a Dedicated Redis Cluster/p" README.md); [ -n "$s" ] && grep -qi "0.2.8" <<<"$s" && grep -qi "chain" <<<"$s" && grep -qi "host name" <<<"$s" && grep -q "ssl: true" <<<"$s" && grep -q "cache.existing" <<<"$s" && grep -q "ranker.cache" <<<"$s" && grep -q "addr" <<<"$s" && grep -qi "layout" <<<"$s" && grep -qi "ranker" <<<"$s" && grep -qi "summary" <<<"$s"'
- [x] 1.2 In the same note, state that plain `redis://` (including the Redis the chart installs) is unaffected and that a certificate chaining to a public root needs no action.
  check: bash -c 's=$(sed -n "/^#### Upgrading to Chart 0.2.8 with a /,/^#### Deploying a Dedicated Redis Cluster/p" README.md); [ -n "$s" ] && grep -q "redis://" <<<"$s" && grep -qi "unaffected" <<<"$s" && grep -qi "public root" <<<"$s" && grep -qi "no action" <<<"$s"'

## 2. The private-CA remedy

- [x] 2.1 State that an operator with a private-CA certificate, or a host name the certificate does not cover, must act before upgrading: a Secret, in the release namespace, with the CA certificate under key `ca.crt` referenced by `fileAccess.caSecretName` (adding the Redis CA to the existing Secret's `ca.crt` when `fileAccess.caSecretName` is already set), or a corrected `addr`; that the CA is mounted from `fileAccess.caSecretName` and a chart that still requires `fileAccess.enabled` for that mount needs a release that removes it; and that skipping it makes ingest, search and summary requests fail and the workers stop publishing and consuming.
  check: bash -c 's=$(sed -n "/^#### Upgrading to Chart 0.2.8 with a /,/^#### Deploying a Dedicated Redis Cluster/p" README.md); [ -n "$s" ] && grep -q "ca.crt" <<<"$s" && grep -q "fileAccess.caSecretName" <<<"$s" && grep -qi "before upgrading" <<<"$s" && grep -qi "private CA" <<<"$s" && grep -qi "publishing" <<<"$s" && grep -qi "consuming" <<<"$s" && grep -q "release namespace" <<<"$s" && grep -qi "already set" <<<"$s" && grep -q "fileAccess.enabled" <<<"$s" && grep -qi "ingest, search and summary requests" <<<"$s"'
- [x] 2.2 State that the CA file replaces the container's default CA file, so the bundle keeps the public roots and any CAs already in it that the same pods still need.
  check: bash -c 's=$(sed -n "/^#### Upgrading to Chart 0.2.8 with a /,/^#### Deploying a Dedicated Redis Cluster/p" README.md); [ -n "$s" ] && grep -qi "replaces the container" <<<"$s" && grep -qi "public roots" <<<"$s"'

## 3. Which clients verify, and what the note must not say

- [x] 3.1 State that the extract client (AGE-395) and the workspace runner do not yet verify, so verification is not presented as platform-wide.
  check: bash -c 's=$(sed -n "/^#### Upgrading to Chart 0.2.8 with a /,/^#### Deploying a Dedicated Redis Cluster/p" README.md); [ -n "$s" ] && grep -q "AGE-395" <<<"$s" && grep -qi "workspace runner" <<<"$s" && grep -qi "extract" <<<"$s"'
- [x] 3.2 The note documents no verification toggle and does not say chart 0.2.7 mounts the CA.
  check: bash -c 's=$(sed -n "/^#### Upgrading to Chart 0.2.8 with a /,/^#### Deploying a Dedicated Redis Cluster/p" README.md); [ -n "$s" ] && ! grep -qi "ssl_cert_reqs" <<<"$s" && ! grep -qi "disable verification" <<<"$s" && ! grep -qi "skip verification" <<<"$s" && ! grep -q "0.2.7" <<<"$s"'

## 4. Scope and gate

- [x] 4.1 The change touches `README.md` only: `README.md` differs from the merge base with `origin/0.2.8` and nothing under `src/`, `helm/`, `.build/` or `helm-releases/` does.
  check: bash -c 'b=$(git merge-base HEAD origin/0.2.8) && git diff --name-only "$b" -- README.md | grep -qx README.md && [ -z "$(git diff --name-only "$b" -- src helm .build helm-releases)" ]'
- [ ] 4.2 The repo's pre-push gate (`.build/bin/validate-helm.sh`) passes on the branch, run by the pre-push hook with helm v3.19.0 and a real python3 on PATH.
  check: n/a — the gate executes a repo script in a privileged repo; the pre-push hook owns it and the pipeline does not run it as an acceptance check

## 5. Merge order

- [ ] 5.1 Confirm the GX-130 on-prem change (the CA mount no longer gated on `fileAccess.enabled`) is merged or merges with this PR before this PR merges.
  check: n/a — merge-order gate owned by the orchestrator, not a runnable command in this repo

See workspace `openspec/changes/gx-131-ai-server-enforce-redis-tls-verification-and-refresh/tasks.md` for cross-service coordination and deferred items.
