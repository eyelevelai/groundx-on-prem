## Implementation

- [x] 1.1 Add the overlap note next to the summary `updateStrategy: Recreate` paragraph in `docs/upgrades.md`: during the upgrade introducing `initializing.flock`, an old pod restarting while old and new pods overlap can load alongside a new one; `summary.inference.updateStrategy: Recreate` or scaling summary-inference to zero removes the overlap (link the existing scale-to-zero steps; no new section).
  check: grep -Eq 'initializing\.flock' docs/upgrades.md && grep -Eqi 'old pod.*(alongside|overlap)|overlap.*old pod' docs/upgrades.md
- [x] 1.2 Add the file-lock storage note in "Summary GPU sizing", next to the sentence saying pods on more than one node need ReadWriteMany storage for the model volume claim (not under "Inference model downloads", which is about the separate download lock): summary-inference needs file-lock support on its model volume, tested on EFS only; on storage that rejects locks the worker logs `model load failed; exiting worker` and restarts so summary does not come up; remedy is a storage class with lock support or rolling the chart back.
  check: grep -Fq 'model load failed; exiting worker' docs/upgrades.md && grep -Eqi 'tested on EFS only' docs/upgrades.md
- [x] 1.3 Confirm no chart, template, values, schema, snapshot or `helm/` file changed and no heading was added to `docs/upgrades.md`.
  check: test -z "$(git diff --name-only origin/0.3.0...HEAD -- src helm helm-releases)" && test "$(git diff origin/0.3.0 -U0 -- docs/upgrades.md | grep -c '^+#')" = 0 && grep -Fq 'initializing.flock' docs/upgrades.md

Checks 1.1 and 1.2 grep the guide for text that does not exist on the unchanged docs, so they fail before the edit; 1.3 includes the same presence assertion so it also fails first. No acceptance stub file is needed beyond these commands (no test tree exists for prose).

See workspace `openspec/changes/gx-114-summary-inference-model-load-lock-two/tasks.md` for cross-service coordination and deferred items.
