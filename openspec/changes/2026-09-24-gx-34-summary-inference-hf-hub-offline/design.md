## Goals / Non-Goals

**Goals:**
- Make `summary-inference` startable, and able to serve a real summarization request, with no
  HuggingFace credential present anywhere in its environment or persistent storage.
- Change nothing about `layout-inference` or `ranker-inference`, which share this template.

**Non-Goals:**
- Rebuilding the `g34b` artifact or rotating the leaked token — needs HuggingFace account access
  this change does not have; tracked on GX-34, owned separately.
- Any change to how the engine-selection config (`engines.<name>.service`/`baseUrl`/`apiKey`)
  routes a summarization request to this pod. Unrelated to the HuggingFace dependency.

## Decisions

- **Root cause (evidence, `groundx-validation`, 2026-09-24):** `summary-inference`'s logs show it
  loading `google/gemma-3-4b-it` successfully from the local cache, then on every restart making a
  live HTTP call to `huggingface.co` to re-check `chat_template.jinja`. That file does not exist
  for this model; the HuggingFace client already recorded that fact in the local cache's
  `.no_exist` marker during the original authenticated download, but re-verifies it on every
  process start rather than trusting the cached answer. Because Gemma's repo is gated, that
  re-verification call itself requires authentication — with the credential deleted, it returns
  `401` (`huggingface_hub.errors.GatedRepoError`), and the pod's readiness probe fails
  indefinitely (`RESTARTS: 0`, permanently `0/1`, confirmed over 6+ minutes of `503`s).

- **Fix site:** `src/groundx/templates/app/inference.yaml` renders `layout-inference`,
  `ranker-inference`, and `summary-inference` from one shared `range` loop
  (`groundx.inference.services`). The container `env:` block (currently one static `POD_NAME`
  entry) gains a second entry, gated on `{{- if eq $mapPrefix "summary" }}`, since `$mapPrefix` is
  already in scope per-service (`"summary"` / `"ranker"` / `"layout"`) and is the cleanest existing
  variable to key the condition on — no new value, no new helper.
  ```yaml
            {{- if eq $mapPrefix "summary" }}
            - name: HF_HUB_OFFLINE
              value: "1"
            {{- end }}
  ```
  `HF_HUB_OFFLINE` is a setting the HuggingFace client library (already inside the existing pinned
  image) understands natively — confirmed via `ai-server`'s `summary/tasks/inference.py`, which
  reads `HF_HOME` but has no code of its own referencing `HF_HUB_OFFLINE` at all, so this is a
  library-level behavior switch, not an application code path. **No image rebuild, no `ai-server`
  change.**

- **Why not a values-driven toggle:** `ranker-inference` already has a materially identical gap
  (`USE_TF` must be set by hand after every upgrade, since the chart has no `env` key for that
  service either — a known, separately tracked issue). Following the same shape here (hardcoded,
  scoped by `mapPrefix`) is consistent with the existing pattern rather than introducing a second,
  inconsistent mechanism. A generic per-service `env` override in values.yaml is a larger, separate
  piece of work (would also fix the `ranker`/`USE_TF` gap) and is out of scope for this fix.

- **Trade-off, worth knowing before debugging a future failure:** `HF_HUB_OFFLINE=1` is permanent,
  not conditional, so `summary-inference` will never fall back to a live HuggingFace fetch for
  anything again, not just the `chat_template.jinja` check this fix targets. That is safe today
  because every file the pinned image needs is already in the local cache; if a future model
  rebuild or image version ever needs a file the cache does not already have, this setting turns
  that into a hard startup failure instead of a normal online fetch — the opposite failure mode
  from the one this fix closes.

- **Verified on real infrastructure before this proposal was written**, not just by template
  inspection: deleted the credential on a running `groundx-validation` pod, set
  `HF_HUB_OFFLINE=1` via `kubectl set env`, forced a full restart, and confirmed (a) the pod reached
  `1/1 Running` with no credential present, (b) no `GatedRepoError`/`401` anywhere in its logs, and
  (c) a real test document summarized successfully end to end through the normal ingest pipeline.
