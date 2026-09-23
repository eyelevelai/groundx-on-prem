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
| `cognito.mode`                              | The identity mode: `apiKeyOnly` (default, unset), `cognito`, or `local`          | unset (`apiKeyOnly`)                  |

## Identity modes

`cognito.mode` selects how customers authenticate, in addition to the API-key access every mode
supports:

- **`apiKeyOnly`** (default, unset) and **`cognito`** — unchanged from today.
- **`local`** — a MySQL-backed local password-login option, requiring a cashbot-go image that
  supports the `local` mode. A customer registers and signs in with a password; on a correct
  password the response body is the customer object (no login token is issued). An admin
  (superaccess API key) resets an existing customer's password directly — there is no
  self-service password change and no email/SES-based reset flow.
- In every mode, customers keep using API keys for GroundX API access unchanged, and
  `admin.password` is **not** an admin-login credential — the admin always authenticates by API
  key, never by password.

Set `cognito.mode: local` only after upgrading the cashbot-go image to a version that supports it
(the chart accepts any string value and does not validate it — cashbot-go rejects an unrecognized
mode at its own startup).
