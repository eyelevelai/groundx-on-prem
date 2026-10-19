## ADDED Requirements

### Requirement: Reconciled release artifacts preserve chart behavior

The 0.2.7 release source SHALL retain main's generated Ingress backend routing and the release branch's managed-data TLS configuration and Secret-backed workspace configuration. The unpacked helm directory SHALL contain exactly the files in the rebuilt main chart archive, with matching contents.

#### Scenario: Both branches' chart behavior is retained

- **GIVEN** the source chart after branch reconciliation
- **WHEN** the existing production Helm gate runs
- **THEN** generated Ingress backends name their rendered API Services and workspace TLS and Secret assertions pass

#### Scenario: Unpacked chart matches the release archive

- **GIVEN** the rebuilt groundx-0.2.7.tgz
- **WHEN** its regular files are compared with helm after removing the archive's groundx prefix
- **THEN** file sets and bytes match exactly, and source tests excluded by .helmignore are absent
