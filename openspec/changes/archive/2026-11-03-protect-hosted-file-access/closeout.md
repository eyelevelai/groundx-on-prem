# Closeout

GroundX 0.2.9 is published from commit `c7852fdba794c95c2f328115ce2945c576c57ac9`. The GitHub release and public Helm repository contain the same chart, with SHA-256 `58359f2d87844395faa0cec1fbda4a2473dc0f9ec5f25d77cd6cd64e80c4d087`. Chart and application versions are 0.2.9. All 16 default application image tags exist. Main CI and the existing 551 chart tests passed.

The release and merged-branch cleanup are complete. This OpenSpec change is closed. Unchecked tasks are deferred, not completed, and no additional work is scheduled by this change:

- Live MinIO, AIStor and S4 version, private-origin, TLS, encryption, sharing and transport qualification. AIStor requires a license.
- Installed SDK, migration-hook and worker compatibility, private ingestion, extraction, copying and callbacks, including Arcadia legacy, Arcadia v1, generic v1 and ADP v1 workloads.
- Store-specific capacity and Redis measurements, local/delegated MCP, browser/QC and named-customer acceptance.
- Optional future Terraform adoption of existing hosted delivery resources, subject to its own reviewed proposal. It is not required to close this release.

Cloud and rendered-chart results do not certify these unrun on-prem scenarios. Their original unchecked entries remain in tasks.md as the historical record; archive does not mark them successful.

Private validation and publication roots were removed. Bounded receipts are retained locally under openspec/runs/protect-hosted-file-access. The publication receipt is also attached to [release 0.2.9](https://github.com/eyelevelai/groundx-on-prem/releases/tag/0.2.9) as 0.2.9-verification.json. No runtime, infrastructure, schema or published artifact changes are part of this closure.
