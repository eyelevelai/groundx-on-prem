## Gateway endpoint loop admission

Storage and signing endpoint admission checks both the public presentation host
and the enabled fileAccess.ingress.hostName. Host comparison is case insensitive
and ignores endpoint ports, matching ingress routing. Disabled ingress contributes
no additional delivery host; disabled fileAccess retains the legacy path. Valid
independent storage/signing endpoints continue to render.

The source helper under src/groundx was changed first and copied byte for byte
into helm. Two new render regressions failed on the baseline because storage and
signing endpoints naming a separate enabled ingress host were accepted. The
focused suite passes all 16 cases after the guard, including valid independent
endpoints, disabled ingress and disabled gateway settings.

Full production chart validation passes with 440 tests and 850 unchanged
snapshots, including dual-surface contract and mirror checks. The explicit
minikube render and git diff --check pass. These are local configuration checks;
no cluster, image publication, SDK repin or deployment is included.

Arcadia legacy, Arcadia v1, generic v1 and ADP v1 extraction workflows, runtime,
prompt policy, task chains, schema routing and immutable output fixtures are
unchanged. This admission guard cannot establish their transport acceptance.
Exact-version storage/backend integration, compatible SDK/image adoption,
protected flow transport and customer acceptance remain the existing release
gates recorded in tasks.md.
