# Terminal extract diagnostics

Terminal extract diagnostics are disabled by default. Enable the same value on
the extract API, agent, download, and save pods with:

```yaml
extract:
  terminalAgentTraceEnabled: true
```

Override one pod by setting `extract.api.terminalAgentTraceEnabled`,
`extract.agent.terminalAgentTraceEnabled`,
`extract.download.terminalAgentTraceEnabled`, or
`extract.save.terminalAgentTraceEnabled`. An explicit pod value wins over the
shared value, including `false`.

Use this only with an Extraction Agents image that implements the
[AGE-272 terminal diagnostics contract](https://github.com/eyelevelai/extraction-agents/pull/101).
The runtime keeps successful work unchanged, publishes Celery failure callbacks
before terminal persistence, and applies the rollout's storage, access,
lifecycle, and failure-budget gates.
