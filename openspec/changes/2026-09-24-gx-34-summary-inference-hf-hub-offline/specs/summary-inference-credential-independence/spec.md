## ADDED Requirements

### Requirement: `summary-inference` MUST NOT require a live HuggingFace credential to start

The `summary-inference` container SHALL be configured so that it can load its model and become
ready using only its local, already-populated model cache, with no HuggingFace credential file
present and no dependency on a successful call to `huggingface.co` succeeding.

#### Scenario: Credential absent, model cache already populated

- **GIVEN** `summary-inference`'s persistent model cache already contains the downloaded model
  (weights, tokenizer, and config files) with no `token` or `stored_tokens` file present
- **WHEN** the pod starts (including a full restart, not just a fresh install)
- **THEN** it reaches a healthy, ready state and can serve a summarization request, without making
  any HuggingFace call that requires authentication

#### Scenario: `layout-inference` and `ranker-inference` are unaffected

- **GIVEN** the same shared template renders `layout-inference` and `ranker-inference`
- **WHEN** either pod's environment is inspected
- **THEN** neither carries the `HF_HUB_OFFLINE` variable added for `summary-inference`, and neither
  services's rendered manifest changes as a result of this change
