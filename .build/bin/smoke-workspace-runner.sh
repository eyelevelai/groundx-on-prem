#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-eyelevel}"
WORKSPACE_SERVICE="${WORKSPACE_SERVICE:-workspace-api}"
PARTNER_SELECTOR="${PARTNER_SELECTOR:-app=groundx}"
DEFAULT_RUNNER_URL="http://${WORKSPACE_SERVICE}.${NAMESPACE}.svc.cluster.local"

normalize_url() {
  local value="$1"
  if [[ "${value}" =~ ^https?:// ]]; then
    printf "%s" "${value}"
  else
    printf "http://%s" "${value}"
  fi
}

RUNNER_URL="$(normalize_url "${RUNNER_URL:-${WORKSPACE_RUNNER_BASE_URL:-${DEFAULT_RUNNER_URL}}}")"
EXPECTED_PARTNER_URL="$(normalize_url "${EXPECTED_PARTNER_URL:-${WORKSPACE_RUNNER_BASE_URL:-${DEFAULT_RUNNER_URL}}}")"

echo "Checking workspace runner service: ${RUNNER_URL}"
kubectl -n "${NAMESPACE}" get service "${WORKSPACE_SERVICE}" >/dev/null
kubectl -n "${NAMESPACE}" rollout status "deployment/${WORKSPACE_SERVICE}" --timeout=180s

for worker in provision workspace command publish cleanup; do
  deployment="workspace-${worker}"
  echo "Checking worker deployment: ${deployment}"
  kubectl -n "${NAMESPACE}" rollout status "deployment/${deployment}" --timeout=180s
done

echo "Checking workspace runner /health from inside the cluster"
smoke_pod="workspace-runner-smoke-$(date +%s)"
kubectl -n "${NAMESPACE}" run "${smoke_pod}" \
  --rm \
  --attach=true \
  --quiet=true \
  --restart=Never \
  --image=curlimages/curl:8.10.1 \
  --command -- curl -fsS "${RUNNER_URL}/health"

partner_pod="$(
  kubectl -n "${NAMESPACE}" get pod \
    -l "${PARTNER_SELECTOR}" \
    -o jsonpath='{.items[0].metadata.name}'
)"

if [[ -z "${partner_pod}" ]]; then
  echo "No Partner API pod found for selector ${PARTNER_SELECTOR} in namespace ${NAMESPACE}" >&2
  exit 1
fi

echo "Checking Partner API pod wiring in ${partner_pod}"
actual_url="$(
  kubectl -n "${NAMESPACE}" exec "${partner_pod}" -- sh -c 'printf "%s" "${WORKSPACE_RUNNER_BASE_URL:-}"'
)"

if [[ "${actual_url}" != "${EXPECTED_PARTNER_URL}" ]]; then
  echo "Expected WORKSPACE_RUNNER_BASE_URL=${EXPECTED_PARTNER_URL}, got ${actual_url:-<empty>}" >&2
  exit 1
fi

echo "Checking Partner API pod can reach workspace runner"
kubectl -n "${NAMESPACE}" exec "${partner_pod}" -- sh -c "wget -T 10 -qO- '${EXPECTED_PARTNER_URL}/health' >/dev/null"

echo "Workspace runner smoke test passed."
