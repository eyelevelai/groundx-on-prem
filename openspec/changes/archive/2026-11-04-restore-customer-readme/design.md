## Baseline and approach

Use [the historical README](https://github.com/eyelevelai/groundx-on-prem/blob/aecde7bc63029f936f85051de023c0aa10a9a798/README.md) as the editorial baseline. Its 697 lines contain roughly 3,400 words; the current README at `eb8be39b7e68f0945c2da0ee857299e933b7e9f2` has 1,121 lines and roughly 9,300 words. Preserve the earlier language and structure rather than writing a new marketing page.

`AGENTS.md` was first authored in `4b078dd131ab43cf9bca12e3fae5e1a9422ee770` and merged in `41705c044f70911d24bb770f583196cca47d3c32`. The latter's first parent has the same README content as the selected baseline. The baseline is an editorial reference, not a command or version to deploy.

Keep the baseline's main sequence: What is GroundX, Installing GroundX, Autoscaling & Monitoring, Using GroundX, and the short Terraform section updated to explain its current supported role. Its autoscaling and simulated-response sections already existed before agent guidance; do not classify them as unwanted additions merely because they are technical. Retain their baseline treatment unless a specific readability or accuracy issue warrants moving detail.

## Content placement

| Content | Treatment |
|---|---|
| Product explanation, ingest/search descriptions, diagrams and calls to action | Reuse baseline wording and placement. Change only inaccurate, outdated or unsafe statements; do not substitute generic marketing copy. |
| Cluster requirements, GPU/storage choices and basic service installation | Preserve the baseline's ordered installation path. Update current sizing, AIStor/OpenSearch requirements and commands. Keep necessary prerequisites and security warnings beside their steps. |
| Application configuration, Helm installation and first use | Keep in the README using baseline phrasing where accurate. Retain supported `licenseKey`, the minimal starter, required credentials, file-access checks and the instruction to retain existing values on upgrades. |
| Extended Redis, OpenSearch and StorageClass upgrade instructions | Put the detailed procedures in `docs/upgrades.md` if existing guides do not already own them. Link existing database and storage migration guides rather than duplicating their procedures. Keep short warnings and links in the README. |
| Optional Workspace configuration and runtime details | Put in `docs/workspace.md`; place contributor-only test commands in `CONTRIBUTING.md`. Preserve all configuration and safety information. |
| Terminal extraction diagnostics | Put in `docs/extract-diagnostics.md`, with prerequisites, exact settings, limitations and verification. Link from a short reference list. |
| Terraform EKS version policy and extended infrastructure maintenance | Put in `terraform/aws/README.md`. Keep the baseline's short Terraform entry, updated to distinguish infrastructure provisioning/maintenance from Helm application deployment. Reuse existing EKS cost and diagnostic guides. |
| Identity, file access, storage migration, large-file delivery, post-processing and monitoring guides | Reuse their current homes and improve links. Do not rename folders or move existing guides merely for naming consistency. |
| Full values reference, service examples and contributor procedures | Keep their existing owners: `helm/README.md`, values examples, `CONTRIBUTING.md` and the linked agent guide. |

The four proposed topic files are destinations for existing content, not four new manuals to write from scratch. If a suitable existing owner is found, extend it instead. Do not create a new directory hierarchy or a second documentation index; use a short reference list in the README and the existing agent indexes.

## Two audiences, shared facts

Humans enter through the README and follow clearly titled guides when needed. Guides explain when they apply, what is required, what to do and how to verify success. Preserve exact commands and useful technical details after the plain-English explanation.

Agents use the same guides and chart sources. `AGENTS.md` links to repository working rules; the Harness on-prem skill retains its discovery questions, deployment decisions and safety checks. No separate AI copy of each customer procedure is introduced. Actual supported behavior comes from the chart/schema and owning application code, not from historical prose.

Existing information must remain findable. Review the current README section by section: retain, relocate, correct against current evidence, or consolidate a duplicate into its existing owner. Preserve unique instructions, known limits, migration ordering and rollback steps. Leave a short link under an established heading where old anchors or external callers still need it. Do not treat later content as disposable based on its date or author.

## Updates and maintenance

Verify old keys, storage provider instructions, credentials, model/GPU requirements and release labels against the current target release. Historical commands and examples must not restore insecure defaults or unsupported fields. Preserve established product language unless a factual or safety reason requires an update. Do not guess commercial or release-status claims when sources disagree; retain or flag the wording for owner verification.

In the on-prem repository guide, add one maintenance rule: when changing deployment behavior or moving instructions, check the relevant `groundx-studio-harness/skills/groundx-on-prem/` references and update those affected, or note that they remain accurate. In the Harness maintenance reference, state the reciprocal rule and link the on-prem documentation entrypoints. Link those detailed rules from the existing indexes; do not expand `AGENTS.md` into a manual.

This is written guidance, not automated synchronization. Do not introduce new scanners, scheduled checks, mandatory companion PRs, cross-repo CI, source manifests or generated customer documentation. Keep existing checks. If an existing check hardcodes a moved README command, update only that check's source path to the owning guide without weakening its assertion. Harness source edits use its existing bundle generation, versioning and validation process; publishing a source change does not imply installed plugins have updated.

## Dependencies and validation

Before moving sections, update inbound links and affected location-specific OpenSpec requirements. In particular inspect `s4-storage-type`, `object-store-install-and-upgrade`, `existing-redis-tls-upgrade-guidance`, `summary-inference-gpu-sizing`, `eks-cluster-version-config`, and active Workspace documentation requirements. Preserve their substantive requirements rather than letting an old README-location rule reinsert a long procedure later.

Use ordinary review and current tools: compare the final README with both the baseline and current version; check links and retained anchors; inspect commands and values against current sources; render the configured starter only if its examples change; run strict OpenSpec validation and `git diff --check`. For Harness edits run the existing on-prem scanner with `GROUNDX_ON_PREM_PATH` set to the exact target checkout, normal validation and the existing plugin-mirror check. Do not add a new test suite for prose placement.

Review a fresh install, an existing-customer upgrade and a reader following an old README link. Check that essential prerequisites remain visible and that relocated procedures still contain their warnings and rollback steps. This is documentation verification, not proof of a live customer deployment. Arcadia legacy, Arcadia v1, generic v1 and ADP v1 extraction runtime, schemas, workflows, prompts and fixtures are unaffected.
