# shared-google-credentials Specification

## Purpose

Allow Google OCR and large-file delivery to share one credential source without
coupling their enablement or changing existing per-service credentials.

## Requirements

### Requirement: Google credentials can be shared without consumer coupling
The chart SHALL accept one shared Google credential file or existing Secret. The managed Secret SHALL exist while either OCR or delivery uses it, and SHALL NOT render without a consumer.

#### Scenario: Delivery without OCR
- **WHEN** delivery selects shared credentials and OCR is disabled
- **THEN** delivery mounts the shared credentials and no OCR mount is required

#### Scenario: Both consumers
- **WHEN** OCR and delivery select the managed shared source
- **THEN** one shared credential Secret supplies both consumers
- **AND** no credential bytes enter the common Go configuration or unrelated workloads

#### Scenario: No consumers
- **WHEN** neither enabled consumer selects the shared source
- **THEN** no shared Secret or mount is rendered

### Requirement: Existing credential configuration remains supported
Legacy OCR paths and delivery Secret references SHALL retain their behavior. Per-service settings SHALL override shared defaults. Ambiguous or missing explicitly selected sources SHALL fail rendering.

#### Scenario: Separate credentials
- **WHEN** OCR has its own credential path and delivery has its own Secret reference
- **THEN** each uses its own source even when a shared source is configured

### Requirement: Shared credential rotation updates consumers
Managed shared credential changes SHALL change the pod credential hash for each consuming workload. Existing external Secret rotation SHALL retain the existing explicit OCR restart procedure.

#### Scenario: Managed file rotation
- **WHEN** the shared JSON file changes
- **THEN** consuming layout and delivery pod templates change
- **AND** unrelated pod templates do not change
