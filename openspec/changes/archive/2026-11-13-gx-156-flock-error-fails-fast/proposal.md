## Why

The `download-model` lock loop (`until flock -n 9; do ... done`) treats every `flock -n` failure as another pod holding the lock. Busybox `flock -n` exits 1 both on contention and on any other error, such as a model volume that does not support file locks. In the error case the pod logs "Download in progress by another pod. Waiting...", retries for 60 minutes and then reports a timeout "waiting for another pod", so an operator hunts for a lock holder that does not exist.

## What Changes

- The loop captures `flock`'s error output: `until err=$(flock -n 9 2>&1); do`. Contention prints nothing and keeps the current wait. Any printed error ends the init container at once with exit 1 and the message `Cannot lock <lock>: <error>. The model volume must support file locks.`
- `src/groundx/templates/app/inference.yaml` changes and is copied byte-for-byte into `helm/templates/app/inference.yaml`; the `inference_test.yaml.snap` (31 copies) and `ranker_test.yaml.snap` (1 copy) golden snapshots are hand-patched.
- No new script file, test file, value or image. The lock is taken in a command substitution subshell; a `flock` lock belongs to the open file description that fd 9 shares, so it stays held after the subshell exits.

## Capabilities

### Modified Capabilities
- `inference-model-download-lock`: a `flock -n` failure that prints an error is fatal at once instead of being retried until the 60-minute limit.

## Impact

- **Blast radius:** the layout, ranker and summary inference pods on chart 0.3.0. Only the error branch changes; contention, the 60-minute limit, the marker short-circuit and the missing-`flock` check are unchanged.
- **Behaviour change:** a volume whose `flock` fails with an error now shows `Init:Error` / `Init:CrashLoopBackOff` with the `flock` error at once, instead of an hour of "Download in progress by another pod".
- **Out of scope:** the deprecated `terraform/groundx-operator` copies, which still use the older `downloading` file script.
