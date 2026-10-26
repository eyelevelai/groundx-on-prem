## MODIFIED Requirements

### Requirement: README takes operator-supplied OpenSearch passwords
The README `### OpenSearch` install step SHALL take an operator-supplied admin password as a bcrypt hash in the Secret `opensearch-internal-users` (key `internal_users.yml`) and state that the plaintext of the same password must be provided to GroundX as `search.privilegedPassword` in values or as `SEARCH_INIT_PASSWORD` in the cluster credentials Secret. `OPENSEARCH_INITIAL_ADMIN_PASSWORD` SHALL NOT be part of the install, because with `DISABLE_INSTALL_DEMO_CONFIG=true` the image's entrypoint no longer runs the demo installer that reads it. The README `### Configuration` minimal-keys block SHALL list `search.password` and `search.privilegedPassword` as set through values or the cluster credentials Secret when `mode` is not `ingest`, and the paragraph after it SHALL state that:
- each search credential can be set via values or via the Secret (`SEARCH_PASSWORD`, `SEARCH_INIT_PASSWORD`), as the `MYSQL_*` keys in the sample Secret do for `db`;
- the Secret route requires `cluster.secrets` to list `eyelevel-secret-credentials`;
- passwords delivered through the Secret are not render-validated by the chart, because the published-default check sees values only;
- the Secret route needs `groundx` and `process` images that read `SEARCH_PASSWORD` and `SEARCH_INIT_PASSWORD`, because both services log in to OpenSearch: the default images are tagged with the chart's `appVersion`, images up to 0.2.7 do not read these keys, and until the chart ships images that do the operator either sets both passwords in values or sets both `groundx.image` and `process.image` to images built from cashbot-go with this change (EyeLevel-ai/cashbot-go#1809), otherwise the API has no search password and crash-loops and the indexing worker cannot write to OpenSearch;
- pods read the Secret only when they start, so after changing either Secret key the operator restarts `groundx` first, waits for it to update the `search.username` user, then restarts `process`;
- the Secret route applies to the direct-helm route, and the Terraform operator still takes both passwords as values.

The README SHALL carry a migration note for existing installs: an existing OpenSearch keeps the admin password it was first initialised with, so, when those are non-default, set the admin password (`search.privilegedPassword` or `SEARCH_INIT_PASSWORD`) to the current admin password and the application password (`search.password` or `SEARCH_PASSWORD`) to the current application password, then rotate (if either current value is a published default the chart rejects it when it is supplied through values, so rotate the admin off it first and choose a new application password); a wrong admin password makes the GroundX API crash-loop at startup when it has to create or update its user (a first install or an application-password change), and is otherwise silent rather than fail the render.

#### Scenario: OpenSearch step asks for a password hash (polarity: reject before state)
- **WHEN** the README `### OpenSearch` section is read
- **THEN** it names `opensearch-internal-users`, `search.privilegedPassword` and `SEARCH_INIT_PASSWORD`
- **AND** it does not name `OPENSEARCH_INITIAL_ADMIN_PASSWORD` as an install input and contains no password or hash value

#### Scenario: Configuration block lists both passwords as values or Secret (polarity: reject before state)
- **WHEN** the README `### Configuration` section is read
- **THEN** it lists `search.password` and `search.privilegedPassword` as set through values or the cluster credentials Secret when `mode` is not `ingest`
- **AND** it no longer says rendering fails until both are set

#### Scenario: README states the Secret route and its limits (polarity: reject before state)
- **WHEN** the README `### Configuration` section is read
- **THEN** it names `SEARCH_PASSWORD`, `SEARCH_INIT_PASSWORD` and `cluster.secrets`
- **AND** it states that Secret-delivered passwords are not render-validated and that the Terraform operator still takes the passwords as values
