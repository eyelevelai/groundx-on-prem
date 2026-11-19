## Design

The workflow calls `.build/bin/validate-helm.sh` without reporting arguments.
The script runs the existing Helm suite once, followed by its existing
snapshot stability and chart contract checks. Job failure still blocks
`On-Prem PR checks`, and test results remain available in Actions logs.

Removing the optional report from CI is smaller than changing the gate's
local reporting interface. No configured repository consumer needs the XML.
The cost is losing the downloadable JUnit artifact from workflow runs.

## Validation and rollout

Run actionlint and compare parsed workflow jobs and steps against the base:
only the gate argument and artifact upload may change. No chart rerun is
needed locally because the gate script and chart inputs are unchanged.
Merge into `0.3.0` through a draft PR; subsequent runs use the new command.
Revert the workflow change to restore reporting. No deployment is required.
