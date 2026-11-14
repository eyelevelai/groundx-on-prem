## 1. The Workspace runner paragraph

- [x] 1.1 Add a paragraph to the "Redis TLS upgrades" section of `docs/upgrades.md` stating that a Workspace runner image that includes the AGE-403 fix verifies a `rediss://` Redis for its broker and result backend and trusts a private CA through `SSL_CERT_FILE`.
  check: bash -c 's=$(sed -n "/^## Redis TLS upgrades/,/^## OpenSearch/p" docs/upgrades.md); grep -q "AGE-403" <<<"$s" && grep -q "SSL_CERT_FILE" <<<"$s" && grep -qi "broker and result backend" <<<"$s"'
- [x] 1.2 In the same paragraph, tell the operator to check the `workspace-*` logs for `certificate verify failed` when the selected image verifies.
  check: bash -c 's=$(sed -n "/^## Redis TLS upgrades/,/^## OpenSearch/p" docs/upgrades.md); grep -q "workspace-\*" <<<"$s" && grep -q "certificate verify failed" <<<"$s"'
- [x] 1.3 State that a `workspace.celeryBrokerUrl` or `workspace.celeryResultBackend` URL that sets an `ssl_*` option stops the pods at startup.
  check: bash -c 's=$(sed -n "/^## Redis TLS upgrades/,/^## OpenSearch/p" docs/upgrades.md); grep -q "workspace.celeryBrokerUrl" <<<"$s" && grep -q "workspace.celeryResultBackend" <<<"$s" && grep -q "ssl_\*" <<<"$s"'
- [x] 1.4 The paragraph states no release number and documents no verification toggle.
  check: bash -c 'l=$(grep "AGE-403" docs/upgrades.md); [ -n "$l" ] && ! grep -qE "chart [0-9]|0\.[0-9]+\.[0-9]+" <<<"$l" && ! grep -qi "ssl_cert_reqs" docs/upgrades.md'

## 2. Scope and gate

- [x] 2.1 The change touches documentation and `openspec/` only: nothing under `src/`, `helm/`, `.build/` or `helm-releases/` differs from the merge base with `origin/0.3.0`.
  check: bash -c 'b=$(git merge-base HEAD origin/0.3.0) && [ -z "$(git diff --name-only "$b" -- src helm .build helm-releases)" ]'
- [ ] 2.2 The repo's pre-push gate (`.build/bin/validate-helm.sh`) passes on the branch, run by the pre-push hook.
  check: n/a — the gate executes a repo script in a privileged repo; the pre-push hook owns it and the pipeline does not run it as an acceptance check

## 3. Merge order

- [ ] 3.1 Before review, merge the latest `origin/0.3.0` into the branch; open PRs that edit `docs/upgrades.md` on the same base touch nearby paragraphs.
  check: n/a — a review-time merge step, not a behavior of the change
