## MODIFIED Requirements

### Requirement: Feature credentials reach only storage consumers
The chart SHALL import the feature storage Secret only into verified Go, migration, layout and extraction consumers, including the optional post-process worker. Explicit operator global and workload Secret imports SHALL retain their existing scope.

#### Scenario: Storage consumers without dependency wait containers
- **GIVEN** file access has a storage Secret and no operator global Secrets
- **WHEN** workloads render
- **THEN** the gateway, upload and other Go storage clients, migration hook, layout and extraction receive that Secret
- **AND** ranker API/inference, summary API/inference, workspace and metrics do not.

#### Scenario: Operator global Secret and ambient AWS credentials
- **GIVEN** an explicit operator global Secret or native S3 with an empty feature storage Secret
- **WHEN** workloads render
- **THEN** operator global imports remain available to every workload, duplicate imports are absent and ambient S3 creates no empty Secret reference.

#### Scenario: Post-process worker with file access enabled (accept and enqueue)
- **GIVEN** file access is enabled with a feature storage Secret and `postProcess.enabled` is true
- **WHEN** either chart surface renders
- **THEN** the `post-process` Deployment `envFrom` includes that Secret
- **AND** the `src/groundx` and `helm` template copies stay byte-identical.

#### Scenario: Post-process worker with file access disabled (skip unrelated path)
- **GIVEN** file access is disabled and `postProcess.enabled` is true
- **WHEN** the chart renders
- **THEN** the `post-process` Deployment has no storage Secret `envFrom` entry and its rendered output is unchanged
- **AND** no workload outside the existing consumer list gains the Secret.
