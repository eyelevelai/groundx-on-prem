# Runtime credential cleanup rollout

## Source and existing applications

Runner PR 12 merged as `8a6e9b4dcada503468e19f8496be14aad349cb02`.
Scaffold PR 15 merged as `b26a0eb4c6404e846ab3fc7702b9d24a63bf60ab`.
Build run `34884598777` succeeded and produced multi-architecture runner digest
`sha256:17e8e3e7abce8972b95886e190beb48239df9c26659b5eb7b7601e50766aaf02`.

The 18 active managed repositories received the cleanup workflow on both main
and their active workspace branches. `source-refs.json` records all 36 pushed
refs. Independent GitHub reads verified each ref and workflow SHA-256
`42d13356df0330176bdd5870d0652ec0bd90a62aed95c453e4bce2e4a7998502`.
No push-triggered workflow ran for these commits. Automatic deployment was
suppressed with `[skip ci]`; this was not a CI verification run.

Four legacy repositories needed migration. GroundX RAG Chat and the original
Studio wireframes had artifact-only build workflows and no uninstall workflow.
Insurance Fraud Inspector and Valantor Website Redeploy received release-scoped
cleanup instead of namespace deletion, plus the two ownership fields in their
credential writer. Existing application credentials were not modified.

The merged workflow's seven executable shell tests passed. Deployment-asset
checks passed on all 18 default branches that have the check (16 checks).
Active-branch checks passed except Insurance Fraud Inspector's existing
middleware Service assertion, reproduced unchanged against its prior source.
GroundX v2 UI's full local test suite passed. No application source, schema,
shared credential, or customer data changed.

## Deployment preparation

The rollout is serialized with AGE-350 against the `groundx` release in
`eyelevel`, cluster `eyelevel_890ng3`, account `903713046261`.
Revision 378 is the baseline. The chart is recovered from its Helm release
record, retaining current templates, files, schema, metadata, and values.

Helm's reused-value handling initially reintroduced `reasoning_effort=None`
into extraction configuration. Explicitly passing the already-saved null value
for `extract.agent.model.reasoningEffort` preserves the deployed omission.
Server-side preview then proved the only manifest and configuration changes
are the six Workspace image overrides. No extraction workload restart is needed.

Revision 379 deployed successfully on 2026-09-14. All six Workspace deployments
have one updated, available replica at the verified immutable digest. A normal
workflow-status request through the Partner facade succeeded after rollout.

## Disposable development test

Project `age344-cleanup-check-20260914`, named
`AGE-344 disposable cleanup check 20260914`, uses caller mode, no AI requests,
private services, and the existing development records, objects, and cache
providers. No additional shared service was provisioned.

The initial GitHub repository creation triggered the scaffold's main-branch
deployment. It stopped at the missing customer credential before applying any
app Secret or Helm release. Its two image tags require cleanup with the two
development tags when the test ends.

Initial deploy-config rejected empty GitHub variable values. Retrying with
only non-empty variables completed successfully as
`operation-9b538ae2-ba4d-45b0-9881-eb47143ef5c0`.
An unrelated node scale-down briefly removed the sole Workspace API pod,
causing facade connection refusals before this runner rollout. The replacement
pod restored service without a configuration change.

Development publish `34886474898` succeeded at app commit
`9747f2b3464b639a757241584fbc10f31b311135`. Frontend-proxied health returned
caller mode, no GroundX runtime keys, and successful actual write/read/delete
readiness probes for records, objects, and cache. Both services are private
ClusterIP services, with no Ingress.

Ordinary teardown `operation-a78fedf4-5fbe-47c7-b1f8-72bd7b99ae08`
dispatched uninstall run `34886831202`, which succeeded. Independent reads
found no app deployments, pods, services, or ingresses. The runtime Secret
kept UID `bba816af-1246-4ff8-8f7b-758d19de42fe` and identical credential bytes.

Republication `34886981021` succeeded at the same app commit. The development
storage probes again passed through the frontend health route, and the runtime
Secret retained its UID and every credential byte. Production provider settings
remain empty.

Permanent deletion `operation-816d0d9c-c6ad-4a3b-a3af-961606cedef5` succeeded
at 19:44 UTC on 2026-09-14. The runner confirmed uninstall runs `34888588128`
(dev) and `34888678119` (prod), then deleted the managed repository. The dev
run exercised owned credential deletion; the prod run exercised the absent
release/credential path. Neither needed manual resource deletion.

Independent reads confirmed no test project, workspace instance, data intent,
allocation, or purge marker. Only its successful cleanup operation receipt remains.
The RDS database and database user are absent, the S3 prefix is empty, and the
IAM and ElastiCache users are absent. The shared cache user group is active.
GitHub returns not found for the test repository while a known existing repository
remains readable with the same installation token.

Both app namespaces remain active. The test app has no remaining deployments,
pods, services, ingresses, or Secrets in either namespace. All 150 unrelated
Secrets retained their identities and bytes across final deletion.

The four disposable frontend/middleware image tags were deleted from ECR Public.
This does not delete shared image repositories or claim removal of all untagged
registry layers.

## Operational follow-up

A failed local Secret inventory command printed encoded credential data into
diagnostic task output. The first affected Secret is `groundx-v2-dev-middleware`.
Those credentials require rotation. No credential values are retained in this
rollout record or committed artifacts. Subsequent inventory commands suppress
raw error output and retain hashes only.
