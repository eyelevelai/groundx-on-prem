## Goals / Non-Goals

**Goals:** an interrupted download never blocks later pods; a failed download never produces a marker; the first upgrade cannot overlap old and new lock mechanisms silently; the behaviour is guarded in the existing gate. Grounded in `proposal.md`.

**Non-Goals:** heartbeat or stale-lock takeover, a `downloading/` directory lock, new values or schema keys, Recreate strategy, the `terraform/groundx-operator` copies, GX-114, harness docs. No new service, table, queue, status model or reaper.

## Decisions

**Invariant (guard class and mirror sweep).** A model volume is marked `complete.<model>` only when the process holding the lock finished every download and extraction successfully, and a lock is held only by a live process. The check must test those meanings: a stale lock file does not block, a failed step leaves no marker, and the lock is a write-opened fd (not the presence of a file, and not the path form that never acquires on EFS). The spec carries the matching catches and must-not-block scenarios (stale `downloading` vs live holder; path-form flock vs fd form; mirror drift vs identical surfaces).

1. **fd-based busybox flock.** `exec 9>>"$lock"; flock -n 9` on `$dir/download.lock`. The lock file is never removed (removal would split waiters across two inodes). EFS evidence: the path form `flock FILE cmd` fails with `Bad file descriptor` on EFS because it opens read-only; the fd form on a write-opened descriptor held and released across nodes (`jg_docs/GX-125/GX-125-efs-flock-test.md`). Other RWX storage is untested; the README says so.
2. **Non-blocking retry loop, not `flock` blocking.** Blocking `flock 9` cannot distinguish a rejected lock from contention and cannot enforce the 60-minute bound. `flock -n 9` rc=1 with empty stderr is contention (retry every 3 s); any other rc, or any stderr text, exits 1 at once. stderr goes to a `mktemp` file inside the model volume (never a subshell, so the lock stays on the script's own descriptor), removed by an `EXIT` trap. The deadline is a script constant `wait_limit=3600` (owner-confirmed 60 minutes in the ticket thread).
3. **Fail fast order.** The `complete.<model>` short-circuit first (exit 0 when present, as today), then `command -v flock`, then the lock. A busybox without flock therefore never fails a pod whose model volume is already complete; only a pod that needs to download fails promptly, naming flock, before any wait or download. If `cgr.dev/eyelevel.ai/busybox-fips:latest` lacks flock, the README remedy applies; there is no bypass value.
4. **Re-check after acquiring.** After the lock is taken the script tests `complete.<model>` again, so a waiter behind a successful holder exits without downloading.
5. **Holder self-repair.** Inside the lock the holder removes `downloading` and `<base>.tar.*` before downloading. Runtime self-repair of this init container's own leftovers, not cluster volume cleanup.
6. **Fail loudly.** The per-part child shell exits 1 on a download failure after 3 attempts and on a `tar` failure; the parent captures the `xargs` status and exits 1 without a marker. Archives are removed and `complete.<model>` written only afterwards, with fd 9 still open, so the lock is released at process exit after the marker exists.
7. **Rollout.** No `updateStrategy` change. Old pods use the `downloading` file and ignore `download.lock`; new pods ignore `downloading`. The two must not overlap mid first download, so the README says scale to 0 before upgrading and before rolling back. A volume that already has `complete.<model>` is safe in both directions.
8. **Guard design (`src/groundx/tests/files/verify-download-model-lock.sh`).** Renders `layout-inference`, `ranker-inference` and `summary-inference` from `src/groundx` and `helm/` (minikube values plus search credentials, as `verify-probe-mirror-drift.sh`), asserts the scripts identical, then runs the `summary-inference` script in the chart busybox image (read from the rendered init container) with `--network none`, a stub `wget` first on `PATH` (shown to intercept before use), and the invoking user's uid. Cases: 1 stale lock, 2a failed wget, 2b failed tar, 3 fresh start, 4 live holder then waiter, 5 two concurrent starts, 6 static fd form and 3600 constant, 7a flock missing and no marker (a symlink-farm `PATH` without the applet; fails fast naming flock), 7d flock missing and marker present (exits 0 without downloading), 7b flock stub that prints an error, 7c flock stub that exits 1 silently (must keep waiting). Case 7 stubs flock and so does not prove the real applet in `busybox-fips`.
   - **Named Docker volumes, not bind mounts.** On a Docker Desktop development machine a host bind mount did not give mutual exclusion between two containers (the second `flock -n` acquired), while a named volume did. The guard therefore uses named volumes for the model volume and the stub state, created `chmod 777` by a root helper container and removed by an `EXIT` trap, along with the labelled containers. The scratch directory for stubs sits under `$HOME` because Docker Desktop shares only certain host paths.
   - The wget stub records each requested URL to a state volume so "downloaded once" is asserted by count, not by log text.
   - Fails closed naming `helm`, `yq` or `docker`; pulls the chart busybox image when absent.
   - Cases 1, 2a, 2b, 6, 7a, 7b and 7c fail on the unchanged template; cases 3, 4, 5 and 7d pass on it by design (they pin behaviour that must not regress).
9. **Snapshots.** `inference_test.yaml.snap` (31 copies) and `ranker_test.yaml.snap` (1 copy) are hand-patched by substituting each recorded script with the new script rendered with that copy's working directory, base name, model version and part list; verified with `helm unittest` without `-u` on a copy of `src/groundx` (never in the worktree) and then `verify-helm-snapshots.py`. AGENTS.md forbids `-u`.
10. **Gate wiring.** A new step in `.build/bin/validate-helm.sh` right after the probe-mirror step, announced exactly as `==> Verifying download-model flock lock and failed-download handling (see GX-125)` (the meta-repo classifier keys on this text) and listed in the script's usage text. `AGENTS.md` lists Docker beside `yq` as a gate prerequisite. CI's `ubuntu-latest` has Docker and the chart image is public. No workflow change.
11. **Compatibility class.** The change is Breaking only in behaviour (failed download now fails the pod, a missing flock fails the pod); there is no schema, value or API change. The compatibility mechanism is the README scale-to-0 procedure plus the rendered-script mirror, not a flag. Producer contract: none; independent service.
12. **No ADR.** The decisions are local to one init script and recorded here; the ticket thread holds the rejected heartbeat design.

## Risks

- `cgr.dev/eyelevel.ai/busybox-fips:latest` may lack flock; unverified here (registry credentials needed). Before-merge item in `proposal.md`; fails promptly and visibly if so.
- Whole-node loss: EFS releases a dead client's locks after its lease; the 60-minute wait covers it. Downloads longer than 60 minutes make waiters end in `Init:Error` and retry; accepted.
- The 60-minute branch has no executed test (waiting it out is not practical); the guard checks the constant and the loop shape only.

## Reference script

The script below is the shape verified against the guard (all cases, run with it spliced into both chart copies). It is the body of the `download-model` `command[2]`; `{{ ... }}` are the existing template variables (`$wd`, `$mv`, `$bn`, `$mpr`).

```sh
dir={{ $wd }}/hf_models_cache
lock="$dir/download.lock"
marker="$dir/complete.{{ $mv }}"
wait_limit=3600

if [ -f "$marker" ]; then
  echo "Model cache already exists. Skipping download."
  echo "Model load done."
  exit 0
fi

if ! command -v flock >/dev/null 2>&1; then
  echo "flock is not available in this busybox image; the model download lock needs it. Use a busybox image that provides flock." >&2
  exit 1
fi

errf=$(mktemp "$dir/.flock-err.XXXXXX") || { echo "Cannot create a scratch file in $dir; the model volume must be writable." >&2; exit 1; }
trap 'rm -f "$errf"' EXIT
exec 9>>"$lock" || { echo "Cannot open $lock for writing; the model volume must support file locks." >&2; exit 1; }

start=$(date +%s)
announced=0
while :; do
  flock -n 9 2>"$errf" && break
  rc=$?
  if [ "$rc" -ne 1 ] || [ -s "$errf" ]; then
    echo "flock failed on $lock (exit $rc): $(cat "$errf")" >&2
    exit 1
  fi
  if [ $(( $(date +%s) - start )) -ge "$wait_limit" ]; then
    echo "Timed out after ${wait_limit}s waiting for another pod to finish downloading the model." >&2
    exit 1
  fi
  if [ "$announced" -eq 0 ]; then
    echo "Download in progress by another pod. Waiting..."
    announced=1
  fi
  sleep 3
done

if [ -f "$marker" ]; then
  echo "Model cache ready."
  echo "Model load done."
  exit 0
fi

echo "Model downloading started..."
rm -f "$dir/downloading" "$dir"/{{ $bn }}.tar.*

echo "{{ $mpr }}" | tr ' ' '\n' | xargs -n 1 -P 5 -I {} sh -c \
  'MAX_RETRIES=3; RETRIES=0; SUCCESS=0; PART={}; URL=https://upload.groundx.ai/{{ $bn }}/model/current/{{ $mv }}.tar.gz.part.$PART; \
  while [ $RETRIES -lt $MAX_RETRIES ]; do \
    echo "Download [attempt $RETRIES] {{ $bn }}.tar.gz.part.$PART"; \
    wget -q -O {{ $wd }}/hf_models_cache/{{ $bn }}.tar.gz.part.$PART $URL && { echo "Downloaded {{ $bn }}.tar.gz.part.$PART successfully."; SUCCESS=1; break; }; \
    echo "Failed to download $URL. Retrying..."; RETRIES=$((RETRIES + 1)); sleep 3; \
  done; \
  [ $SUCCESS -eq 0 ] && { echo "Failed to download $URL after $MAX_RETRIES attempts. Exiting."; exit 1; }; \
  echo "Unzipping {{ $bn }}.tar.gz.part.$PART..."; \
  tar -xzf {{ $wd }}/hf_models_cache/{{ $bn }}.tar.gz.part.$PART -C {{ $wd }}/hf_models_cache/ || { echo "Failed to unzip {{ $bn }}.tar.gz.part.$PART. Exiting."; exit 1; }; \
  echo "Unzipping {{ $bn }}.tar.gz.part.$PART complete...";'
xrc=$?
if [ "$xrc" -ne 0 ]; then
  echo "Model download failed (xargs exit $xrc). No completion marker written." >&2
  exit 1
fi

rm -f "$dir"/{{ $bn }}.tar.* || { echo "Failed to remove downloaded archives." >&2; exit 1; }
touch "$marker" || { echo "Failed to write $marker." >&2; exit 1; }

echo "Model load done."
```
