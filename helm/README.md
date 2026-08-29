# GroundX Helm Chart

## Installing GroundX

Instructions on how to install GroundX On-Prem can by found in the main [README.md](/README.md#installing-groundx).

## values.yaml

The following table lists the configurable parameters of the GroundX chart and their default values.

| Parameter                                   | Description                                                                     | Default                               |
|---------------------------------------------|---------------------------------------------------------------------------------|---------------------------------------|
| `groundxLicense`                            | An API key from the GroundX account you wish to associate with this deployment  | **must be set**                       |
| `namespace`                                 | The namespace where the helm charts and application will be installed           | `eyelevel`                            |
| `ingestOnly`                                | If `true`, only ingest-related pods and services will be installed              | `false`                               |
| `admin.apiKey`                              | A UUID that will be associated with the admin account in this deployment        | `00000000-0000-0000-0000-000000000000`|
| `admin.username`                            | A UUID that will be associated with the admin account in this deployment        | `00000000-0000-0000-0000-000000000000`|
| `admin.email`                               | The password associated with the admin account in this deployment               | `support@mycorp.net`                  |
| `admin.password`                            | The email associated with the admin account in this deployment                  | `password`                            |
| `extract.terminalAgentTraceEnabled`         | Enables terminal-only private diagnostics for every extract pod                  | `false`                               |
| `extract.<pod>.terminalAgentTraceEnabled`   | Overrides the shared diagnostic value for api, agent, download, or save           | inherited                             |

## Anthropic workflow engines

Use the existing engine and extraction-agent fields:

```yaml
engines:
  default:
    engineId: claude-sonnet-4-20250514
    service: anthropic
    baseUrl: https://api.anthropic.com/v1/messages

extract:
  agent:
    serviceType: anthropic
    apiBaseUrl: https://api.anthropic.com/v1/messages
    modelId: claude-sonnet-4-20250514
```

Supply the summary provider key through `engines.<name>.apiKey` or
`summary.existing.apiKey`. Supply the extraction provider key through
`extract.agent.apiKey`, `extract.agent.existingSecret`, or `cluster.secrets`. Do not
commit credentials to a values file.

Upgrade note: per-engine `engines.<name>.service` now takes effect and wins over the
legacy `serviceType` field when both are set. Review custom engine values containing
either field before upgrading.
