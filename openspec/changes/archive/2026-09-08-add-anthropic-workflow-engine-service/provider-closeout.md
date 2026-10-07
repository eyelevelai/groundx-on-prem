# Anthropic provider validation

Native Anthropic completed production text and image canaries, followed by the full ADP V4 canary on Haiku 4.5. The ADP run completed 476 page-extraction calls, seven reconciliation groups, seven QA groups, final save and raw readback. Provider validation passed. Its 85/102 field score is informational; further accuracy testing is outside this closeout.

Helm revision 352 uses the existing 41,943,040-byte image-payload default. The 10 MiB override was removed from both ignored operator values files and the live release. The extract-agent environment was the only changed manifest value; 58 other resources and all images were unchanged. `image-payload-default.md` and `source-text-release.md` record deployment provenance and rollback.

## Cleanup

- Deleted isolated synthetic buckets 33447 and 33448 and workflows `a8500c47-5388-4ef5-9645-d0073fd07200` and `478ae621-c59b-484f-8ab6-c8871a3e19bc`.
- The ADP closeout also deleted buckets 33471 and 33472 and their model-specific workflows. All four buckets contained exactly ten canary documents/retries, with no workflow assigned elsewhere. DELETE returned 200; subsequent bucket/workflow GETs returned 400, confirming absence.
- Retained successful text/image boundary fixtures at `openspec/work/add-anthropic-workflow-engine-service/prod-20260908/source-text-retest/`. All 145 text and 146 image trace objects pass their saved hashes. Existing small deployment evidence remains in the parent runtime root and `image-payload-default-20260908/`.
- Evidence owner: release coordinator. Retention review: 2026-09-15, not automatic deletion authorization. Local evidence is ignored and not committed. Hosted bucket deletion is irreversible; direct storage-object deletion was not performed.
- Removed the clean, fully contained `AGE-336-deploy` and `age336-page-window-limit` worktrees, the obsolete `fix/age336-page-window-limit` local branch, and a stale worktree registration. Merged Anthropic PR remote branches were already absent. Active PR branches and unrelated work remain untouched.

## Future deployments

Implementation and opted-in production provider validation are complete. Task 4.4 is closed. Before upgrading another environment, its operator must check custom engine values and runtime-image compatibility. The service-key precaution remains in both chart READMEs. Other deployments have not been certified, and no further ADP accuracy run is required for provider validation.

The full `.build/bin/validate-helm.sh` gate passes on the closeout branch. No chart template, source/mirror pair, image, credential or production default-provider setting changes in this PR. The two credential-bearing operator values files remain ignored.
