## MODIFIED Requirements

### Requirement: The existing-Redis section carries a chart 0.2.8 verified-TLS upgrade note

`README.md` SHALL carry, inside "Using an Existing Redis Cluster" and before "Deploying a Dedicated Redis Cluster", a `####` upgrade note titled "Upgrading to Chart 0.2.8 with a `rediss://` Redis". The README note SHALL warn about the verification change and link `docs/upgrades.md#redis-tls-upgrades`. The full note in that guide SHALL state that chart 0.2.8 ai-server images (the layout, ranker and summary services, APIs and workers) verify the certificate chain and host name of a `rediss://` Redis, that this applies when `ssl: true` is set under `cache.existing`, under the ranker-only `ranker.cache`, or under `cache.metrics.existing` for a separate metrics Redis, and the certificate must cover the `addr` host name of each, and that plain `redis://`, including the Redis the chart installs, is unaffected. It SHALL state that a certificate chaining to a public root needs no action. It SHALL NOT document any setting that turns verification off.

#### Scenario: The note states the behavior change and who is unaffected (polarity: finalize success)

- **GIVEN** the README on this branch
- **WHEN** a reader follows the upgrade-note link under "Using an Existing Redis Cluster"
- **THEN** it says chart 0.2.8 images verify chain and host name for `rediss://`, that plain `redis://` and the bundled Redis are unaffected, and that a publicly rooted certificate needs no action

#### Scenario: The note offers no way to skip verification (polarity: reject before state)

- **GIVEN** the same note
- **WHEN** a reader looks for a setting that disables verification
- **THEN** none is documented; the only remedies named are supplying the CA or correcting the host name, and the opposite outcome (a documented `ssl_cert_reqs=none` or equivalent toggle) does not appear

### Requirement: The note states which clients verify and which do not yet

The linked note SHALL preserve the chart 0.2.8 rollout findings for layout, ranker and summary verification, and identify the original extract client (AGE-395) and Workspace non-verification finding as historical. It SHALL require checking the selected images rather than claiming either platform-wide verification or current non-verification without evidence.

#### Scenario: The unverified clients are named (polarity: skip unrelated repair path)

- **GIVEN** the same note
- **WHEN** a reader checks whether every Redis client now verifies
- **THEN** the note names the original extract client (AGE-395) and Workspace findings, scopes them to the historical rollout, and requires checking the selected images

## ADDED Requirements

### Requirement: Documentation changes preserve deployment behavior

Documentation relocation SHALL NOT modify any template, values file, schema, snapshot or `helm/` mirror file.

#### Scenario: Deployment files remain unchanged (polarity: reject before state)

- **GIVEN** the branch diff against its merge base with `origin/0.2.8`
- **WHEN** the changed paths under `src/`, `helm/`, `.build/` and `helm-releases/` are listed
- **THEN** the list is empty and changes outside `openspec/` are limited to documentation and its existing references

## REMOVED Requirements

### Requirement: The change touches the README only

**Reason**: The documentation-only invariant now covers the README and its linked guides.
**Migration**: Use the requirement Documentation changes preserve deployment behavior.
