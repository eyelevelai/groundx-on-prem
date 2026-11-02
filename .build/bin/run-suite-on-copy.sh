#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [ "$#" -eq 0 ]; then
  echo "usage: run-suite-on-copy.sh <suite-file-name>..." >&2
  exit 2
fi

HELM="${GX_ON_PREM_HELM:-$(command -v helm || true)}"
if [ -z "${HELM}" ]; then
  echo "helm not found on PATH and GX_ON_PREM_HELM unset" >&2
  exit 2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cp -R "${ROOT_DIR}/src/groundx" "${WORK}/groundx"
mkdir -p "${WORK}/groundx/files/ocr"
cat > "${WORK}/groundx/files/ocr/gcv-test.json" <<'JSON'
{
  "type": "service_account",
  "project_id": "groundx-helm-test",
  "private_key_id": "test",
  "client_email": "test@groundx-helm-test.iam.gserviceaccount.com",
  "token_uri": "https://oauth2.googleapis.com/token"
}
JSON

cd "${WORK}/groundx"
for suite in "$@"; do
  "${HELM}" unittest -f "tests/${suite}" .
done
