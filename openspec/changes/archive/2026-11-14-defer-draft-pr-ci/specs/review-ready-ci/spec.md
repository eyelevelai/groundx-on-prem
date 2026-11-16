## ADDED Requirements

### Requirement: Review-ready regression checks

On-Prem CI SHALL require successful Helm and both kind jobs for the review-ready PR revision, and SHALL preserve branch-push, release and manual validation.

#### Scenario: Ready PR revision

- **WHEN** a human marks a draft ready or updates a ready PR
- **THEN** the PR-only check passes only after Helm and both live Strimzi jobs succeed
