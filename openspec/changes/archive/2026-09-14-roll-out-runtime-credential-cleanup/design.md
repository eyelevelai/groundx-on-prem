## Execution

Inventory active projects from the runner metadata database and inspect every target
workflow before editing. Use repo-scoped git sessions. Preserve unrelated project work
and workflow customizations; verify pushed branches before advancing.

Coordinate with the concurrent AGE-350 Helm rollout. Re-read the latest stable release,
recover its embedded chart, and compare a server-side preview. Only Workspace image
fields may change. Use an immutable image digest and confirm all six deployments ready.

Create one caller-mode, private development test app with no AI calls. Test its ordinary
deployment lifecycle and credential preservation before confirmed permanent deletion.
Verify independently that its workloads, runtime Secret, repository, and metadata are
gone. Do not delete shared TLS or registry Secrets or namespaces.

## Local Work

Owner: AGE-344 operator. Reason: reviewed workflow clones, deployment preview, and
disposable app test. Exact root:
`/Users/benjaminfletcher/git/groundx-on-prem/.worktrees/age-344-purge-rollout/openspec/work/roll-out-runtime-credential-cleanup/live/`.
Expiry: 2026-09-21T00:00:00Z. Keep credentials out of logs and tracked files. Retain
only sanitized outcomes and source refs, then remove transient work before archive.

Disposition: accepted. The operator-owned durable handoff is `rollout.md` and
`source-refs.json` beside this design, containing sanitized outcomes and pushed
source identities. The disposable cloud project has been removed. Retain only
the bounded ignored lifecycle summary and tracked cleanup receipt after local
closeout. Credential rotation from diagnostic output is a separate operational
follow-up, not an uncompleted rollout step.
