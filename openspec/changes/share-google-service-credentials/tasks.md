## Implementation
- [x] Add failing shared credential cases to the existing Helm suites.
- [x] Implement shared source selection, Secret lifecycle, mounts and rotation hashes.
- [x] Preserve legacy OCR and delivery sources; mirror source changes to helm.
- [x] Document shared configuration, permissions and rotation.

## Verification
- [x] Pass the full Helm gate and minikube render on both chart surfaces.
- [x] Verify shared-source rotation, disabled consumers, overrides and isolation.
- [x] Decode shared delivery configuration with Cashbot's existing Go integration test.
- [x] Review the final diff for the 0.2.7 pull request.

Verification passed with `.build/bin/validate-helm.sh`, minikube renders of
`src/groundx` and `helm`, and strict OpenSpec validation. Existing snapshot
entries are unchanged. Cashbot's `TestLargeFileChartConfiguration` passed
against both the legacy fixture and a disposable chart copy using the shared
fixture, on Cashbot commit `60d4ecf8de2253bfefaf1c1f4033a262da3a36dc`.
Only generated fake credentials were used. No live OCR or Drive run is claimed.

## Deployment boundary
No cluster, account policy or Google credential is changed by this implementation.
After merge, canary the selected source in dev and verify both OCR and delivery
before adopting it in other environments. Provision an external Secret before
the upgrade, or supply a private chart-local file. Existing installations need
no migration unless opting in. Keep account routing disabled until its separate
capacity and destination checks pass.
