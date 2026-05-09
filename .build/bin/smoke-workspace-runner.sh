#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-eyelevel}"
WORKSPACE_SERVICE="${WORKSPACE_SERVICE:-workspace-api}"
PARTNER_SELECTOR="${PARTNER_SELECTOR:-app=groundx}"
#RUNNER_URL="${WORKSPACE_RUNNER_BASE_URL:-http://${WORKSPACE_SERVICE}.${NAMESPACE}.svc.cluster.local}"
RUNNER_URL="k8s-eyelevel-workspac-c114e5a5b1-02582dd7d722f588.elb.us-west-2.amazonaws.com"

echo "Checking workspace runner service: ${RUNNER_URL}"
kubectl -n "${NAMESPACE}" get service "${WORKSPACE_SERVICE}" >/dev/null
kubectl -n "${NAMESPACE}" rollout status "deployment/${WORKSPACE_SERVICE}" --timeout=180s

for worker in provision workspace command publish cleanup; do
  deployment="workspace-${worker}"
  echo "Checking worker deployment: ${deployment}"
  kubectl -n "${NAMESPACE}" rollout status "deployment/${deployment}" --timeout=180s
done

echo "Checking workspace runner /health from inside the cluster"
kubectl -n "${NAMESPACE}" run workspace-runner-smoke \
  --rm \
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

if [[ "${actual_url}" != "${RUNNER_URL}" ]]; then
  echo "Expected WORKSPACE_RUNNER_BASE_URL=${RUNNER_URL}, got ${actual_url:-<empty>}" >&2
  exit 1
fi

echo "Checking Partner API pod can reach workspace runner"
kubectl -n "${NAMESPACE}" exec "${partner_pod}" -- sh -c "wget -T 10 -qO- '${RUNNER_URL}/health' >/dev/null"

echo "Workspace runner smoke test passed."
