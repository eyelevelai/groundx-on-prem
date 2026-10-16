## Why

Private file access must operate wholly inside a customer Kubernetes deployment, preserving stable addresses and worker access with MinIO, AIStor and Red Hat S4.

## What Changes

Add optional local gateway deployment and separate stable delivery, internal storage and external native signing endpoints. Use existing storage and GroundX authentication libraries. New uploads in an enabled deployment are private; explicit per-resource protection is still opt-in. Preserve existing values when disabled. Open design questions: none; exact-version compatibility and encryption evidence are release gates.

## Capabilities

### New Capabilities

- `local-file-gateway`: portable gateway deployment, endpoint separation and private-store readiness.

### Modified Capabilities

None.

## Impact

The source is `src/groundx`, with matching published `helm` mirror changes. [Cashbot](related-changes.md#cashbot-go) supplies the gateway/shared policy and client endpoint configuration. [ai-server](related-changes.md#ai-server) supplies private bucket initialization and worker storage endpoint support. This change introduces no AWS dependency and performs no deployment during planning.

## Ingress and credential admission

Enabled file access rejects native storage ingress on the public delivery host or an enabled chart gateway host. The public host remains protected for external gateway routing. Distinct native signing ingress remains supported. Limit the feature storage Secret to verified storage consumers; preserve operator `cluster.secrets`. Invalid colliding configurations fail before rollout, and removing unused Secret imports changes the affected pod specifications. No stateful resources or stored URLs change. Rollback retains private storage and active policy enforcement.
