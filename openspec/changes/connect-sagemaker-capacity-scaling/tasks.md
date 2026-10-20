## Implementation

- [x] Add failing tests for the owning scope.
- [x] Implement opt-in metrics config/schema, source and published mirror with unchanged default behavior.
- [x] Run owning repository checks and a fresh review.
- [x] Record exact-source finite runtime qualification and cleanup evidence.

## Runtime qualification

The isolated Seoul endpoint used the standard AWS vLLM image, unchanged Gemma QAT model and original requests. Native AWS policies increased actual capacity from one ml.g6e.2xlarge instance to two and returned it to one. Each instance has one NVIDIA L40S GPU. The existing metrics binary published GroundX pending-work pressure using actual serving capacity; no additional limiter, gateway or serving image was introduced.

Three 490-request passes measured 23.27, 36.78 and 23.36 requests/minute, with zero errors or retries in each pass. Two additional client calls failed before dispatch during test-host STS connectivity failure; they are retained separately. A follow-up continuous-stream check completed 49 calls with zero errors or retries through native scale-in. Redis failure, CloudWatch publication denial, publisher restart, publication disable and scaling suspension were exercised in isolation. Physical AWS capacity shortage was not forced.

All exact finite compute and temporary helpers were independently verified absent. Historical ledger rows and original first-absence observations remain preserved. Final cumulative conservative estimate is USD 2078.4233, below USD 3000, with actual AWS charges unverified. Customer routing remains unchanged; automatic scale-in remains disabled by default until deployment-owner activation.

Canonical aggregate results are in the valantor-poc repository at adp/evaluations/reviews/gemma4-sagemaker-capacity-scaling-20261020.md and gemma4-sagemaker-active-scale-in-20261020.md. Private phase identities: adp-bm-cap-0142631b20833b and adp-bm-cap-466ba9ab3d99b2. The earlier zero-request start adp-bm-cap-58c27621ed449b is closed and included in costs.
