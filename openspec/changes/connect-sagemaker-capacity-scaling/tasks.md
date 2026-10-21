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

## Native routing repeat

With the infrastructure variant explicitly using LEAST_OUTSTANDING_REQUESTS, the same 490-request passes completed on one, two and one ml.g6e.2xlarge instances, one L40S each, at 23.34, 44.93 and 23.39 requests/minute. All passes had zero errors or extra provider attempts. Two-GPU throughput improved 22.1%, mean latency fell from 9.54s to 7.83s and P95 fell from 19.58s to 14.61s. GPU processing cost fell from USD3.13 to USD2.56 per 1000 successes, excluding startup and idle hosting.

All 1470 measured calls have matched native stage timers. Input timing includes handoff; prefill/decode include scheduling and do not measure pure CUDA busy time. Cache history and instrumentation differ from the prior run. The existing metrics implementation and chart remained unchanged during the repeat. Requests called the normal Cashbot and Arcadia methods directly from the Mac, not production workers.

Canonical results: [native routing comparison](https://github.com/EyeLevel-ai/valantor-poc/blob/06e85d1ac5143ebc61b15f9ada7a2ececdac0180/adp/evaluations/reviews/gemma4-sagemaker-native-routing-20261020.md), with matching CSV/JSON. All exact finite resources are independently verified absent. Final cumulative conservative estimate is USD2243.5820 under USD3000, including stopped setups, with actual AWS charges unverified. Historical financial rows and first GPU-absence evidence remain unchanged. Production activation remains off.
