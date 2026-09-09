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

## Extract model request overrides

Use the existing extraction-agent model kwargs for provider request-body options:

```yaml
extract:
  agent:
    model:
      kwargs:
        extra_body:
          parallel_tool_calls: false
```

This example makes the extraction model call one tool per turn. Workflow
`requestPassthrough` values override matching `extra_body` defaults. The selected
extraction runtime image must support the option.

## Explicit workflow engines

Set the service and only the values required by that provider or self-hosted endpoint.
The chart passes explicit values through without applying provider-specific defaults.
This Anthropic example uses the existing engine and extraction-agent fields:

```yaml
engines:
  default:
    engineId: claude-sonnet-4-20250514
    service: anthropic
    baseUrl: https://api.anthropic.com/v1

extract:
  agent:
    serviceType: anthropic
    apiBaseUrl: https://api.anthropic.com/v1
    modelId: claude-sonnet-4-20250514
```

When authentication is required, supply the summary key through
`engines.<name>.apiKey` or `summary.existing.apiKey`, and the extraction key through
`extract.agent.apiKey`, `extract.agent.existingSecret`, or `cluster.secrets`. Helm does
not require a key or substitute the GroundX admin key for an explicitly configured
service. If the service is omitted, the existing local GroundX defaults apply. Do not
commit credentials to a values file.

## Engine configuration upgrade note

For `engines.<name>`, a non-empty `service` takes precedence over legacy
`serviceType`. When `service` is omitted or empty, `serviceType` still works.
Before upgrading an environment, review engines that set both values and confirm
the selected provider is intended. `extract.agent.serviceType` is unchanged;
without an explicit extraction service, extraction inherits the default summary
engine. Check runtime-image compatibility and retain rollback settings for that
deployment.
