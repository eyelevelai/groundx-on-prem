## Context

GX-125 first split contention from errors with a scratch stderr file and an `EXIT` trap. The 2026-11-04 simplification of that change replaced it with `until flock -n 9; do ... done`, which retries errors until the 60-minute limit with the error in the log. Busybox `flock` (`util-linux/flock.c`) returns `EXIT_FAILURE` silently on `EWOULDBLOCK` and calls `bb_perror_nomsg_and_die()`, also exit 1 with a message on stderr, for any other error, so the exit code alone cannot tell them apart.

## Decisions

1. **Capture stderr in a command substitution.** `until err=$(flock -n 9 2>&1); do`. Empty `err` is contention; non-empty is an error. No scratch file, no trap.
2. **The lock survives the subshell.** `flock` locks the open file description, which the subshell's fd 9 shares with the script's fd 9, so the lock stays held when the subshell exits. Verified in the chart busybox image: after `err=$(flock -n 9 2>&1)` succeeds, a second descriptor opened on the same file is refused with empty stderr.
3. **Fail at once on an error.** `echo "Cannot lock $lock: $err. The model volume must support file locks." >&2; exit 1`. Kubernetes restarts the init container, so a transient error heals on the next start.

## Verification

The Docker guard removed from CI on 2026-11-04 (`verify-download-model-lock.sh`, recovered from `2b6c10e3e^`) is run locally against both chart copies, not committed. On unchanged 0.3.0 case 7b (a `flock` that prints an error is fatal at once) fails with a timeout; with this change every case passes, including 7c (a silent rc=1 `flock` keeps waiting), 4 (waiter behind a live holder), 5 (two concurrent starts) and 8a (holder killed).
