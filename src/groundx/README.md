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
