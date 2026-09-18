## 1. Scope the OCR credential guard to layout workers

- [ ] 1.1 Scope `$mountOCR` in `src/groundx/templates/app/celery.yaml` (line 23) to the layout
  Celery worker only — add `(eq $mapPrefix "layout")` as a leading conjunct, preserving the
  existing `(or (eq $hasOCR "true") $sharedGoogle)` disjunct and `$sharedGoogle`'s own scoping
  (line 22) unchanged — so the `ocr-credentials-hash` annotation (L73/74), the
  `/app/credentials.json` volume mount (L181), and the `credentials-volume` volume (L199/L208)
  are emitted for the layout OCR worker only. The RED regression case is already authored in
  `src/groundx/tests/celery_test.yaml`.
  check:
  ```
  mkdir -p src/groundx/files/ocr && cat > src/groundx/files/ocr/gcv-test.json <<'JSON'
  {
    "type": "service_account",
    "project_id": "groundx-helm-test",
    "private_key_id": "test",
    "client_email": "test@groundx-helm-test.iam.gserviceaccount.com",
    "token_uri": "https://oauth2.googleapis.com/token"
  }
  JSON
  helm unittest -f 'tests/celery_test.yaml' src/groundx
  ```
- [ ] 1.2 Mirror the identical corrected predicate into `helm/templates/app/celery.yaml`
  (byte-identical to `src/groundx/templates/app/celery.yaml`, matching the pre-existing
  byte-identity of this file) so the published chart carries the same fix on both surfaces.
  check: .build/bin/validate-helm.sh

## 2. Confirm compatibility and no schema/DB impact

- [ ] 2.1 No schema, seed, or reference-data change accompanies this fix — template logic only,
  `values.schema.json` and every `values.yaml` default stay untouched.
  check: n/a — no schema/DB change (Helm template predicate scoping only)
- [ ] 2.2 Run the full local gate to confirm the compatibility paths this fix must leave
  byte-identical (shared Google credentials, `google.existingSecret` + its configured key,
  legacy `layout.ocr.credentials` precedence, disabled OCR, and Tesseract without credentials)
  and that the chart test suite passes on both `src/groundx` and `helm` surfaces.
  check: .build/bin/validate-helm.sh

No manual ops, secret change, or canary/stage sequencing beyond a normal chart-version bump is
required — see `proposal.md`'s Rollback/rollforward section. This is an `INDEPENDENT`,
single-repo change with no cross-service coordination to record.
