# Shared Google service credentials

## Why
Google OCR and large-file delivery can use the same service account, but the chart currently ties its managed credential Secret to OCR enablement. Delivery must remain usable when OCR is disabled.

## What changes
Add optional shared Google credentials, supplied as a chart-local JSON file or an existing Secret. OCR can inherit them when its own credential path is absent; delivery explicitly selects them through its named credential registry. Existing per-service credentials retain their behavior. No application authentication changes or cloud deployments are included.

## Impact
Only installations opting into shared credentials change. Shared credentials grant their consumers the same Google service-account permissions. Managed-file updates roll consuming pods; external Secret updates require the operator to restart OCR consumers because their existing mount uses subPath. No database or stored-document changes occur. Rollback restores per-service credential settings before removing the shared source. Changes ship on 0.2.7 in both chart surfaces.

## Open questions
None.
