## ADDED Requirements

### Requirement: Chart exposes engine maxImages config

The chart SHALL allow operators to configure the maximum image attachments for
requests using the default application engine.

#### Scenario: Operator sets maxImages

- **GIVEN** values include `engines.default.maxImages: 20`
- **WHEN** the chart renders application `config.yaml`
- **THEN** the rendered `engines.default` config contains `maxImages: 20`
- **AND** a compatible application uses 20 as the image-count limit for
  requests using that engine.

#### Scenario: Operator omits maxImages

- **GIVEN** values do not include `engines.default.maxImages`
- **WHEN** the chart renders the default engine config
- **THEN** the rendered config does not include `maxImages`
- **AND** a compatible application applies no image-count limit from this
  field.

#### Scenario: Operator sets maxImages to null

- **GIVEN** values include `engines.default.maxImages: null`
- **WHEN** the chart renders the default engine config
- **THEN** the rendered config does not include `maxImages`
- **AND** a compatible application applies no image-count limit from this
  field.

## REMOVED Requirements

### Requirement: Chart exposes document summary maxImages config

**Reason:** `maxImages` now follows normal engine precedence for every request
using the selected engine, and omission no longer invokes an application
fallback.

**Migration:** Configure a positive `engines.default.maxImages` value when a
count limit is required.
