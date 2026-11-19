## Implementation

- [x] Remove `--junit` and its artifact upload from the Helm workflow.
- [x] Move both live Strimzi jobs to release/manual events and remove them from the PR aggregate.
- [x] Restrict push runs to `main` and numeric version branches.
- [x] Group automatic runs by PR or push branch and cancel superseded revisions.
- [x] Isolate release/manual runs from automatic cancellation and pending-run replacement.
- [x] Align contributor guidance and the review-ready CI requirement.
- [x] Validate workflow syntax, scheduling, cancellation groups and unchanged tests against the base.
- [x] Prepare the updated draft PR targeting `0.3.0`.
