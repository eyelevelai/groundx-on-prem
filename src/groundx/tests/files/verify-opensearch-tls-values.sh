#!/usr/bin/env bash
set -euo pipefail

if ! command -v yq >/dev/null 2>&1; then
  echo "FAIL: yq not found on PATH" >&2
  exit 1
fi

SRC=src/groundx/values/opensearch/values.yaml
MIRROR=helm/values/opensearch/values.yaml
HANDSYNCED=(
  values/opensearch/values.yaml
  values.yaml
  values.schema.json
)

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

for rel in "${HANDSYNCED[@]}"; do
  cmp -s "src/groundx/${rel}" "helm/${rel}" || fail "helm/${rel} differs from src/groundx/${rel}"
done

yq -e '.extraEnvs[] | select(.name == "DISABLE_INSTALL_DEMO_CONFIG" and .value == "true")' "${SRC}" >/dev/null \
  || fail "DISABLE_INSTALL_DEMO_CONFIG=true is not set in extraEnvs"

yq -e '.securityConfig.internalUsersSecret != null and .securityConfig.internalUsersSecret != ""' "${SRC}" >/dev/null \
  || fail "securityConfig.internalUsersSecret is not set"

yq -e '.secretMounts | length > 0' "${SRC}" >/dev/null \
  || fail "no secretMounts for the operator certificates"

os_yml="$(yq -r '.config."opensearch.yml"' "${SRC}")"
[[ -n "${os_yml}" && "${os_yml}" != "null" ]] || fail "config.opensearch.yml is not set"

for forbidden in allow_unsafe_democertificates kirk esnode root-ca.pem; do
  if grep -q -- "${forbidden}" <<<"${os_yml}"; then
    fail "config.opensearch.yml still references ${forbidden}"
  fi
done

for required in \
  'plugins.security.ssl.transport.pemcert_filepath: certs/node.crt' \
  'plugins.security.ssl.transport.pemkey_filepath: certs/node.key' \
  'plugins.security.ssl.transport.pemtrustedcas_filepath: certs/ca.crt' \
  'plugins.security.ssl.http.enabled: true' \
  'plugins.security.ssl.http.pemcert_filepath: certs/node.crt' \
  'plugins.security.ssl.http.pemkey_filepath: certs/node.key' \
  'plugins.security.ssl.http.pemtrustedcas_filepath: certs/ca.crt' \
  'CN=gx-opensearch-admin'; do
  grep -qF -- "${required}" <<<"${os_yml}" || fail "config.opensearch.yml lacks: ${required}"
done

for file in "${SRC}" "${MIRROR}"; do
  if grep -q -- '-----BEGIN' "${file}"; then
    fail "${file} carries certificate or key material"
  fi
done

echo "OK: OpenSearch TLS seed values use operator certificates and the helm/ mirror matches"
