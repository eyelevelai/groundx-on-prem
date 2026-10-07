# Hosted extraction image payload default

Remove `extract.agent.maxImagePayloadBytes: 10485760` from both local operator values files and the current hosted Helm configuration. Use the existing chart default of 41943040 bytes. Do not change chart templates, container images, model settings, other release values or historical evidence.

## Execution

- [x] Verify account 903713046261, context gxprod, namespace eyelevel and current deployed release.
- [x] Remove the override from `values.ranker-only-eks.yaml` and `values.ranker-only-eks.original.yaml`. These operator files remain ignored because they contain deployment credentials.
- [x] Render the deployed chart with only that override removed; the only manifest change is the extract-agent environment value from 10485760 to 41943040. The stored chart values also contained 10485760; restore that single default to the pushed chart's 41943040. Other defaults and templates are unchanged.
- [x] Upgrade release 351 to 352, wait for rollout and old workers to exit, and verify live environment and image identity. The production `configured_max_image_payload_bytes()` function returns 41943040. All other 58 resources are unchanged.
- [x] Rerun the unchanged ADP Haiku canary. It completed with all seven reconciliation and QA groups passing, without the image-limit failure. Raw final output scored 85/102 (83.33%). Provider validation passed; accuracy is informational and no other documents were submitted. Evaluation evidence and all 17 scorer differences are recorded under the ADP evaluation plan.
- [x] Remove temporary secret-bearing deployment snapshots after verification. Retain redacted proof and evaluation evidence. Helm revision 351 remains available for rollback.

Private deployment work belongs in `/Users/benjaminfletcher/git/groundx-on-prem/openspec/work/add-anthropic-workflow-engine-service/image-payload-default-20260908`. Retention review is due 2026-09-15, not automatic deletion authorization. The existing ADP evaluation plan owns its separate retry artifacts. The increased image allowance may increase non-Bedrock agent memory use. Historical Helm revisions retain the prior override for rollback and are not configuration sources for new deployments.
