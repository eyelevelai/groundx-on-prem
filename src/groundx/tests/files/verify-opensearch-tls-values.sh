#!/usr/bin/env bash
set -euo pipefail

if ! command -v yq >/dev/null 2>&1; then
  echo "FAIL: yq not found on PATH" >&2
  exit 1
fi

if [[ $# -eq 0 ]]; then
  set -- src/groundx/values/opensearch/values.yaml helm/values/opensearch/values.yaml
fi

fail() {
  echo "FAIL: $1: $2" >&2
  exit 1
}

check_seed() {
  local file="$1"
  [[ -f "${file}" ]] || fail "${file}" "file not found"

  yq -e '.extraEnvs[] | select(.name == "DISABLE_INSTALL_DEMO_CONFIG" and .value == "true")' "${file}" >/dev/null 2>&1 \
    || fail "${file}" "DISABLE_INSTALL_DEMO_CONFIG=true is not set in extraEnvs"

  yq -e '.securityConfig.internalUsersSecret != null and .securityConfig.internalUsersSecret != ""' "${file}" >/dev/null 2>&1 \
    || fail "${file}" "securityConfig.internalUsersSecret is not set"

  yq -e '.secretMounts[] | select(.secretName == "opensearch-tls" and .path == "/usr/share/opensearch/config/certs")' "${file}" >/dev/null 2>&1 \
    || fail "${file}" "secretMounts does not mount opensearch-tls at /usr/share/opensearch/config/certs"

  yq -e '.image.tag | test("@sha256:[0-9a-f]{64}$")' "${file}" >/dev/null 2>&1 \
    || fail "${file}" "image.tag is not pinned to a sha256 digest"

  local parsed
  parsed="$(yq '.config."opensearch.yml" | from_yaml' "${file}" 2>/dev/null)" \
    || fail "${file}" "config.opensearch.yml is missing or is not valid YAML"
  [[ -n "${parsed}" && "${parsed}" != "null" ]] || fail "${file}" "config.opensearch.yml is not set"

  local expr
  while IFS= read -r expr; do
    yq -e "${expr}" <<<"${parsed}" >/dev/null 2>&1 || fail "${file}" "config.opensearch.yml fails: ${expr}"
  done <<'EXPRS'
.["plugins.security.ssl.http.enabled"] == true
.["plugins.security.ssl.transport.pemcert_filepath"] == "certs/node.crt"
.["plugins.security.ssl.transport.pemkey_filepath"] == "certs/node.key"
.["plugins.security.ssl.transport.pemtrustedcas_filepath"] == "certs/ca.crt"
.["plugins.security.ssl.http.pemcert_filepath"] == "certs/node.crt"
.["plugins.security.ssl.http.pemkey_filepath"] == "certs/node.key"
.["plugins.security.ssl.http.pemtrustedcas_filepath"] == "certs/ca.crt"
.["plugins.security.authcz.admin_dn"] | contains(["CN=gx-opensearch-admin"])
.["plugins.security.nodes_dn"] | length > 0
.["plugins.security.nodes_dn"] | contains(["CN=gx-opensearch-admin"]) | not
.["plugins.security.allow_unsafe_democertificates"] == null
EXPRS

  if yq -r '.config."opensearch.yml"' "${file}" | grep -qiE 'kirk|esnode|root-ca\.pem'; then
    fail "${file}" "config.opensearch.yml references demo certificate identities"
  fi

  if grep -q -- '-----BEGIN' "${file}"; then
    fail "${file}" "carries certificate or key material"
  fi
}

for seed in "$@"; do
  check_seed "${seed}"
done

echo "OK: OpenSearch TLS seed values use operator certificates"
