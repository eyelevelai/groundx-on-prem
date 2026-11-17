# Extract agent API key

The extract agent Secret (`extract-agent-secret`, or the Secret named by `extract.agent.secretName`) is rendered last in `envFrom` on `extract-api`, `extract-agent`, `extract-download` and `extract-save`. Kubernetes resolves the last entry, so its `GROUNDX_AGENT_API_KEY` wins over the same key in any Secret listed in `cluster.secrets`, whatever their names or order.

- In-cluster summary engine: the agent Secret is rendered only when `admin.apiKey` is set in values. Supplying the admin key only through a shared Secret renders no agent Secret.
- `extract.agent.existingSecret: true`: every key in that Secret overrides the same key from earlier Secrets on `extract-agent`, `extract-download` and `extract-save`. Keys it lacks still resolve from the shared Secrets.
- Hosted provider with no `apiKey` and no `existingSecret`: no agent Secret is attached, and the shared Secret's key is used.

Upgrading to a chart with this order rolls the extract api, agent, download and save pods once.

## Release dependency

The order ships in chart 0.3.0. Self-hosted extraction against the bundled summary service also needs a summary-api that returns a standard OpenAI chat completion (ai-server, GX-158). The chart's default summary-api image is `python-api:<chart appVersion>`, so build `python-api:0.3.0` from ai-server after that change merges. An earlier image still fails extraction even with the correct key.
