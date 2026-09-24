# Design

Add an array of unique, non-empty domain strings under `integration` in chart values and the strict values schema. Render the array under `integrationTests.extractionCaptureDomains` only when nonempty. Keep `extractionCaptureAccounts` unchanged. The Cashbot handler, not Helm, validates the authenticated account and enforces the capture marker and bucket constraints.

Update `src/groundx` first and mirror the same values, schema, and template into `helm/`. Unit tests cover the default, two configured domains, and invalid value shapes. Run the full Helm validation gate and a minikube render. No chart release or installation is part of the code change.
