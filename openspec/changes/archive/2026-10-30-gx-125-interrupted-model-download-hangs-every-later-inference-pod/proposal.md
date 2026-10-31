## Why

The `download-model` init container in the inference pods guards its first model download with a presence-only `downloading` file. If a pod is interrupted mid-download (eviction, node loss, OOM), the file stays on the shared model volume, and every later inference pod waits on it forever and never starts. Separately, a failed `wget`/`tar` step can still end with `complete.<model>` written, so a pod starts against a broken or partial model. GX-125 replaces the file with an OS-released lock and makes failed downloads fail loudly.

## What Changes

- Replace the `downloading` presence check in the `download-model` script (`src/groundx/templates/app/inference.yaml`, mirrored byte-for-byte in `helm/templates/app/inference.yaml`) with a busybox `flock` on an open file descriptor (`exec 9>>"$lock"; flock -n 9`). The OS releases a dead holder's lock, so a later pod takes over the download.
- Check that `flock` exists before waiting; if it is missing, exit non-zero at once with a message naming flock.
- Retry only silent contention (rc=1) until a 60-minute deadline, then exit non-zero with a clear message. Any `flock -n` failure that prints an error (rejected lock, missing applet, bad fd) is fatal immediately.
- After acquiring the lock, re-check `complete.<model>`; the holder removes any old `downloading` file and partial part files, then downloads.
- Any `wget`, `tar` or `xargs` failure exits non-zero and writes no marker; `complete.<model>` is written while still holding the lock.
- Add a `validate-helm.sh` guard, `src/groundx/tests/files/verify-download-model-lock.sh`, that renders the script from both `src/groundx` and `helm/`, asserts they are identical, and runs it in the chart busybox image via Docker for these cases: stale lock file, failed wget, failed tar, fresh start, shared-file-name parts extracted in order, waiter behind a live holder, holder killed or failing while a waiter waits, the wait deadline, two concurrent starts, static write-fd form, and flock unavailable, rejected or silently contended.
- Hand-patch the `inference_test.yaml.snap` (31 copies) and `ranker_test.yaml.snap` (1 copy) golden snapshots; no `-u` regeneration.
- Add an upgrade note to the root `README.md` under `#### Upgrading an Existing Install`.
- **Behaviour change (not a schema break):** a failed download now ends the pod in `Init:Error` / `CrashLoopBackOff` instead of starting with a broken model, and a waiter that outlasts 60 minutes does the same. The previous lock file is no longer written or honoured.

## Capabilities

### New Capabilities
- `inference-model-download-lock`: the `download-model` init container serialises the first model download with an OS-released file lock, recovers from an interrupted holder, bounds the wait, and never marks a failed download complete.

### Modified Capabilities

None. No existing spec in `openspec/specs/` covers model download behaviour.

## Impact

- **Blast radius:** every environment that upgrades the chart redeploys the inference services (layout, ranker, summary) with the new init script. No new image, value, schema key, service, RBAC or volume.
- **Rollout risk:** old and new pods use different lock mechanisms and must not overlap while a first download is in progress. The README note says to scale the service to 0 and wait until no inference pod remains (Terminating included) before upgrading, and likewise before rolling back to the old chart while a new-chart pod is mid first download. Rollback otherwise is to roll back the chart; model volume contents are unchanged by this change apart from the holder removing leftover `downloading` and part files.
- **Before merge:** confirm `cgr.dev/eyelevel.ai/busybox-fips:latest` ships the `flock` applet (owner confirmation or direct probe; case 7 stubs flock, so it cannot confirm this). If missing, inference services fail promptly and visibly on upgrade, and the README names the fix: a busybox image with flock or storage supporting file locks. There is no value to bypass the lock.
- **Stateful data:** the shared model volume (EFS in the verified setup). Cross-node locking is verified on EFS only. Air-gapped installs must seed the model volume before scaling up, since a failed download no longer starts the pod.
- **Tooling:** `validate-helm.sh` gains a Docker prerequisite (CI `ubuntu-latest` has it). groundx-on-prem is PRIVILEGED, so running the gate prompts for approval. The engineering-context push-gate update is built by the orchestrator, not in this repo.
- **Out of scope:** GX-114 (ai-server model-load lock), `terraform/groundx-operator` copies of the script (deprecated), and groundx-studio-harness on-prem docs (separate follow-up ticket).
- **Open design questions:** none.
