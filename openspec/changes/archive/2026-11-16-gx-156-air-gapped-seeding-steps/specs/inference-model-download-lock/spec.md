## MODIFIED Requirements

### Requirement: The upgrade guide documents the upgrade, rollback and failure behaviour
`docs/upgrades.md` SHALL carry a `## Inference model downloads` section, listed in its index, in plain language covering: scale the inference deployments to 0 and wait until their pods are gone before upgrading or rolling back while a first download is in progress; how to recover a pod that cannot load its model because an older chart marked a failed download complete; how an air-gapped install seeds the model volume (the ranker and summary parts and layout's `init-layout` files downloaded on a connected machine, the service scaled to 0 and its pods gone, a short-lived pod that mounts the claim extracting each part into the volume root and creating `complete.<model>` last for ranker and summary, and the layout files copied in under their own names), that an air-gapped cluster re-seeds instead of re-downloading after deleting a false marker, and that an upgrade that changes a model needs the new model seeded first; and that a custom busybox image must include `flock`. The README's `#### Upgrading an Existing Install` SHALL keep the scale-to-0 warning and link that section. Neither SHALL name a chart version. Polarity: `accept and enqueue`.

#### Scenario: Guide section present and complete
- **GIVEN** `docs/upgrades.md` after the change
- **WHEN** the section is extracted
- **THEN** it is non-empty and contains each of the topics above

#### Scenario: README keeps the warning beside the upgrade step
- **GIVEN** the README after the change
- **WHEN** an operator reads `#### Upgrading an Existing Install`
- **THEN** it tells them to scale the inference deployments to 0 and wait before upgrading or rolling back during a first download, and links `docs/upgrades.md#inference-model-downloads`

#### Scenario: Backward compatibility during rollout
- **GIVEN** an old-chart pod and a new-chart pod running against the same volume during a first download
- **WHEN** an operator follows the upgrade guide
- **THEN** the service is scaled to 0 and every inference pod, Terminating ones included, is gone first so the two lock mechanisms never overlap, and a volume already holding `complete.<model>` is skipped by both versions

#### Scenario: Air-gapped false marker is re-seeded
- **GIVEN** an air-gapped cluster whose model volume holds a false `complete.<model>` left by an older chart
- **WHEN** an operator follows the guide's recovery
- **THEN** it tells them to delete the marker and re-seed the volume from a short-lived pod with the service scaled to 0, and does not rely on the next pod downloading the model
