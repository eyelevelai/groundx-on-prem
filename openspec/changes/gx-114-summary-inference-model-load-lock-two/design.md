## Goals / Non-Goals

Goals: state the old/new pod overlap risk with its remedy, and the file-lock storage requirement with its symptom and remedy, in the operator upgrade guide. Non-goals: any chart, template, values, schema or snapshot change; a new procedure section; detection of lock-less storage before the pod starts; claims about storage other than EFS. See `proposal.md`.

## Decisions

1. **Placement.** Put the overlap note immediately after the paragraph in "Summary GPU sizing" that says `updateStrategy: Recreate` causes an outage on each upgrade (the paragraph beginning "Apply these values to a running install"), and the lock-storage note in the same section, right after the sentence saying pods on more than one node need ReadWriteMany storage for the model volume claim (lock support is the same kind of storage requirement). It does not go under "Inference model downloads", which covers the separate download lock and would invite confusing the two locks. Each stays a few sentences inside an existing section, so no heading is added. The overlap note links to the existing scale-to-zero steps instead of repeating them.
2. **Wording of the storage note.** "Tested on EFS only" is the exact bound: the only evidence is the EFS test, and the failure is stated as a consequence of a lock call that errors, not as detection. An NFS mount that accepts locks without enforcing them across nodes would not produce the error, so the note does not promise that every unsupported storage fails visibly.
3. **Log text.** Quote `model load failed; exiting worker`, the message logged when the load raises (`summary/tasks/inference.py:360` in ai-server).
4. **Release timing.** The note ships only in the chart release whose summary-inference image carries the ai-server lock change. If 0.3.0 is cut first, the note moves to the next release branch (plan assumption).

Producer contract shapes: none; this change has no cross-service touchpoint.

## Existing mechanisms

Adds no config key, flag, class, helper, constant, table, workflow or delivery path. It extends existing prose in `docs/upgrades.md` (the `updateStrategy: Recreate` paragraph and the scale-to-zero steps under "Inference model downloads") and reuses them rather than adding a parallel procedure.
