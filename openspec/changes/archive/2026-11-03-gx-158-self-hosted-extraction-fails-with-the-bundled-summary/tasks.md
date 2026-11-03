## 1. Thin slice: extract-agent, extract-download and extract-save render the agent Secret last

- [x] 1.1 Add `groundx.extract.agent.lastSecret` to `src/groundx/templates/_helpers/app/extract-agent.tpl` and use it in `src/groundx/templates/app/celery.yaml` so the agent Secret is skipped in the sorted range and emitted as the final `envFrom` entry (only when attached to an `extract.*` workload)
  check: helm unittest -f 'tests/extract_agent_key_test.yaml' src/groundx
- [x] 1.2 Hand-patch the `celery_test.yaml.snap` `envFrom` blocks (swap `extract-agent-secret` and `extract-save-secret`); never run `helm unittest -u`
  check: n/a — mechanical snapshot patch, verified by the gate in 5.1 and `.build/bin/verify-helm-snapshots.py`

## 2. extract-api

- [x] 2.1 Apply the same helper in `src/groundx/templates/app/api.yaml` (the range there emits the map key, keep that) so `extract-api` renders the agent Secret last
  check: helm unittest -f 'tests/extract_agent_key_api_test.yaml' src/groundx
- [x] 2.2 Hand-patch the `api_test.yaml.snap` extract-api `envFrom` blocks
  check: n/a — mechanical snapshot patch, verified by the gate in 5.1

## 3. Mirror and cross-surface proof

- [x] 3.1 Mirror the template changes by hand into `helm/templates` (byte-identical to `src/groundx/templates`) and confirm `src/groundx` and `helm/` both resolve `GROUNDX_AGENT_API_KEY` to the summary key
  check: python3 .build/bin/verify-extract-agent-key.py
- [x] 3.2 Wire `.build/bin/verify-extract-agent-key.py` into `.build/bin/validate-helm.sh` after the targeted render checks, and list it in the script's usage text
  check: grep -q 'verify-extract-agent-key.py' .build/bin/validate-helm.sh

## 4. Documentation

- [x] 4.1 README: add a `GROUNDX_AGENT_API_KEY` precedence note (agent Secret last, `existingSecret` keys override, hosted without a key keeps the shared Secret) and the minimum python-api image release that carries the ai-server reply fix
  check: grep -q 'ships in chart 0.3.0' README.md

## 5. Gate

- [x] 5.1 Run the full chart gate (lint, helm unittest with the generated OCR fixture, snapshot stability, mirror and render checks); PRIVILEGED repo, so lint, template and unittest only
  check: .build/bin/validate-helm.sh

See workspace `openspec/changes/gx-158-self-hosted-extraction-fails-with-the-bundled-summary/tasks.md` for cross-service coordination and deferred items (ai-server reply fix, internal-arcadia-agents and cashbot-go verification, cluster proof for acceptance criterion 4).
