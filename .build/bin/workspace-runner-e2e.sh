#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-eyelevel}"
WORKSPACE_SERVICE="${WORKSPACE_SERVICE:-workspace-api}"
WORKSPACE_SERVICE_PORT="${WORKSPACE_SERVICE_PORT:-80}"
LOCAL_PORT="${LOCAL_PORT:-18080}"
BASE_URL="http://127.0.0.1:${LOCAL_PORT}"

WORKSPACE_SECRET="${WORKSPACE_SECRET:-workspace-secret}"
PARTNER_USERNAME="${PARTNER_USERNAME:-workspace-e2e-partner}"
CUSTOMER_USERNAME="${CUSTOMER_USERNAME:-workspace-e2e-customer}"
WRONG_PARTNER_USERNAME="${WRONG_PARTNER_USERNAME:-workspace-e2e-wrong-partner}"
PROJECT_ID="${PROJECT_ID:-workspace-e2e-project-$(date +%s)}"
WORKSPACE_ID="${WORKSPACE_ID:-workspace-e2e-$(date +%s)}"
BRANCH="${BRANCH:-workspace-e2e-$(date +%s)}"
E2E_FILE_PATH="${E2E_FILE_PATH:-workspace-e2e.txt}"
RUN_PUBLISH="${RUN_PUBLISH:-false}"
POLL_TIMEOUT_SECONDS="${POLL_TIMEOUT_SECONDS:-180}"

if [[ -z "${REPOSITORY_URL:-}" ]]; then
  echo "REPOSITORY_URL is required, for example: REPOSITORY_URL=https://github.com/org/repo.git" >&2
  exit 1
fi

decode_base64() {
  if base64 --help 2>&1 | grep -q -- "-d"; then
    base64 -d
  else
    base64 -D
  fi
}

if [[ -z "${WORKSPACE_RUNNER_TOKEN:-}" ]]; then
  encoded_token="$(
    kubectl -n "${NAMESPACE}" get secret "${WORKSPACE_SECRET}" \
      -o jsonpath='{.data.WORKSPACE_RUNNER_TOKEN}' 2>/dev/null || true
  )"
  if [[ -n "${encoded_token}" ]]; then
    WORKSPACE_RUNNER_TOKEN="$(printf "%s" "${encoded_token}" | decode_base64)"
  fi
fi

if [[ -z "${WORKSPACE_RUNNER_TOKEN:-}" ]]; then
  echo "WORKSPACE_RUNNER_TOKEN is required or ${WORKSPACE_SECRET} must contain WORKSPACE_RUNNER_TOKEN." >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
port_forward_pid=""

cleanup() {
  if [[ -n "${port_forward_pid}" ]]; then
    kill "${port_forward_pid}" >/dev/null 2>&1 || true
    wait "${port_forward_pid}" >/dev/null 2>&1 || true
  fi
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

json_get() {
  local file="$1"
  local expr="$2"
  python - "$file" "$expr" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    value = json.load(handle)
for part in sys.argv[2].split("."):
    if part == "":
        continue
    value = value[part]
print(value)
PY
}

api() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local output="$4"
  if [[ -n "${body}" ]]; then
    curl -fsS -X "${method}" "${BASE_URL}${path}" \
      -H "Authorization: Bearer ${WORKSPACE_RUNNER_TOKEN}" \
      -H "X-Partner-Username: ${PARTNER_USERNAME}" \
      -H "X-GroundX-Username: ${CUSTOMER_USERNAME}" \
      -H "Content-Type: application/json" \
      -d "${body}" \
      -o "${output}"
  else
    curl -fsS -X "${method}" "${BASE_URL}${path}" \
      -H "Authorization: Bearer ${WORKSPACE_RUNNER_TOKEN}" \
      -H "X-Partner-Username: ${PARTNER_USERNAME}" \
      -H "X-GroundX-Username: ${CUSTOMER_USERNAME}" \
      -o "${output}"
  fi
}

api_status() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local output="$4"
  local partner="${5:-${PARTNER_USERNAME}}"
  if [[ -n "${body}" ]]; then
    curl -sS -X "${method}" "${BASE_URL}${path}" \
      -H "Authorization: Bearer ${WORKSPACE_RUNNER_TOKEN}" \
      -H "X-Partner-Username: ${partner}" \
      -H "X-GroundX-Username: ${CUSTOMER_USERNAME}" \
      -H "Content-Type: application/json" \
      -d "${body}" \
      -o "${output}" \
      -w "%{http_code}"
  else
    curl -sS -X "${method}" "${BASE_URL}${path}" \
      -H "Authorization: Bearer ${WORKSPACE_RUNNER_TOKEN}" \
      -H "X-Partner-Username: ${partner}" \
      -H "X-GroundX-Username: ${CUSTOMER_USERNAME}" \
      -o "${output}" \
      -w "%{http_code}"
  fi
}

operation_path() {
  local workspace_id="$1"
  local operation_id="$2"
  if [[ -n "${workspace_id}" && "${workspace_id}" != "null" ]]; then
    printf "/workspaces/%s/operations/%s" "${workspace_id}" "${operation_id}"
  else
    printf "/operations/%s" "${operation_id}"
  fi
}

poll_operation() {
  local workspace_id="$1"
  local operation_id="$2"
  local output="$3"
  local deadline=$((SECONDS + POLL_TIMEOUT_SECONDS))
  local status=""
  local message=""
  while (( SECONDS < deadline )); do
    api GET "$(operation_path "${workspace_id}" "${operation_id}")" "" "${output}"
    status="$(json_get "${output}" "workspaceOperation.status")"
    case "${status}" in
      succeeded)
        return 0
        ;;
      failed|canceled)
        message="$(json_get "${output}" "workspaceOperation.message")"
        echo "Operation ${operation_id} ended with ${status}: ${message}" >&2
        cat "${output}" >&2
        return 1
        ;;
    esac
    sleep 2
  done
  echo "Timed out waiting for operation ${operation_id}" >&2
  cat "${output}" >&2 || true
  return 1
}

envelope() {
  local workspace_json="$1"
  python - "$PARTNER_USERNAME" "$CUSTOMER_USERNAME" "$workspace_json" <<'PY'
import json
import sys

print(json.dumps({
    "partnerUsername": sys.argv[1],
    "username": sys.argv[2],
    "workspace": json.loads(sys.argv[3]),
}))
PY
}

echo "Checking workspace runner rollout before E2E"
kubectl -n "${NAMESPACE}" rollout status "deployment/${WORKSPACE_SERVICE}" --timeout=180s
for worker in provision workspace command publish cleanup; do
  kubectl -n "${NAMESPACE}" rollout status "deployment/workspace-${worker}" --timeout=180s
done

echo "Opening port-forward to service/${WORKSPACE_SERVICE} on ${BASE_URL}"
kubectl -n "${NAMESPACE}" port-forward "service/${WORKSPACE_SERVICE}" \
  --address 127.0.0.1 "${LOCAL_PORT}:${WORKSPACE_SERVICE_PORT}" \
  >"${tmp_dir}/port-forward.log" 2>&1 &
port_forward_pid="$!"

for _ in {1..30}; do
  if curl -fsS "${BASE_URL}/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
curl -fsS "${BASE_URL}/health" >/dev/null

echo "Fetching storage status"
api GET /storage "" "${tmp_dir}/storage.json"

echo "Creating project ${PROJECT_ID}"
project_body="$(envelope "{\"projectId\":\"${PROJECT_ID}\",\"repository\":{\"url\":\"${REPOSITORY_URL}\"}}")"
api POST /projects "${project_body}" "${tmp_dir}/project.json"
project_operation="$(json_get "${tmp_dir}/project.json" "workspaceOperation.operationId")"
poll_operation "" "${project_operation}" "${tmp_dir}/project-operation.json"

echo "Creating workspace ${WORKSPACE_ID} from ${REPOSITORY_URL}"
workspace_body="$(envelope "{\"projectId\":\"${PROJECT_ID}\",\"workspaceId\":\"${WORKSPACE_ID}\",\"branch\":\"${BRANCH}\",\"repository\":{\"url\":\"${REPOSITORY_URL}\"}}")"
api POST /workspaces "${workspace_body}" "${tmp_dir}/workspace.json"
workspace_operation="$(json_get "${tmp_dir}/workspace.json" "workspaceOperation.operationId")"
poll_operation "${WORKSPACE_ID}" "${workspace_operation}" "${tmp_dir}/workspace-operation.json"

echo "Writing ${E2E_FILE_PATH}"
write_body="$(envelope "{\"filePath\":\"${E2E_FILE_PATH}\",\"content\":\"workspace runner e2e ${WORKSPACE_ID}\\n\"}")"
api POST "/workspaces/${WORKSPACE_ID}/files/write" "${write_body}" "${tmp_dir}/write.json"
write_operation="$(json_get "${tmp_dir}/write.json" "workspaceOperation.operationId")"
poll_operation "${WORKSPACE_ID}" "${write_operation}" "${tmp_dir}/write-operation.json"

echo "Reading ${E2E_FILE_PATH}"
read_body="$(envelope "{\"filePath\":\"${E2E_FILE_PATH}\"}")"
api POST "/workspaces/${WORKSPACE_ID}/files/read" "${read_body}" "${tmp_dir}/read.json"
grep -q "workspace runner e2e ${WORKSPACE_ID}" "${tmp_dir}/read.json"

echo "Running allowed command"
command_body="$(envelope "{\"command\":{\"command\":\"python\",\"args\":[\"--version\"]}}")"
api POST "/workspaces/${WORKSPACE_ID}/commands" "${command_body}" "${tmp_dir}/command.json"
command_operation="$(json_get "${tmp_dir}/command.json" "workspaceOperation.operationId")"
poll_operation "${WORKSPACE_ID}" "${command_operation}" "${tmp_dir}/command-operation.json"

echo "Checking disallowed command failure"
bad_command_body="$(envelope "{\"command\":{\"command\":\"sh\",\"args\":[\"-c\",\"echo should-not-run\"]}}")"
api POST "/workspaces/${WORKSPACE_ID}/commands" "${bad_command_body}" "${tmp_dir}/bad-command.json"
bad_command_operation="$(json_get "${tmp_dir}/bad-command.json" "workspaceOperation.operationId")"
if poll_operation "${WORKSPACE_ID}" "${bad_command_operation}" "${tmp_dir}/bad-command-operation.json"; then
  echo "Expected disallowed command operation to fail." >&2
  exit 1
fi
grep -q "command is not allowed" "${tmp_dir}/bad-command-operation.json"

echo "Checking diff"
api GET "/workspaces/${WORKSPACE_ID}/diff" "" "${tmp_dir}/diff.json"
grep -q "${E2E_FILE_PATH}" "${tmp_dir}/diff.json"

echo "Checking wrong-owner rejection"
wrong_status="$(api_status GET "/workspaces/${WORKSPACE_ID}" "" "${tmp_dir}/wrong-owner.json" "${WRONG_PARTNER_USERNAME}")"
if [[ "${wrong_status}" != "403" ]]; then
  echo "Expected wrong-owner request to return 403, got ${wrong_status}" >&2
  cat "${tmp_dir}/wrong-owner.json" >&2
  exit 1
fi

if [[ "${RUN_PUBLISH}" == "true" ]]; then
  echo "Running publish operation. This may merge the managed PR if publish_dry_run is false."
  publish_body="$(envelope "{\"publish\":{\"title\":\"Workspace E2E ${WORKSPACE_ID}\",\"description\":\"Automated workspace runner E2E\",\"draft\":true}}")"
  api POST "/workspaces/${WORKSPACE_ID}/publish" "${publish_body}" "${tmp_dir}/publish.json"
  publish_operation="$(json_get "${tmp_dir}/publish.json" "workspaceOperation.operationId")"
  poll_operation "${WORKSPACE_ID}" "${publish_operation}" "${tmp_dir}/publish-operation.json"
else
  echo "Skipping publish. Set RUN_PUBLISH=true to exercise /publish."
fi

echo "Deleting workspace cache"
api DELETE "/workspaces/${WORKSPACE_ID}" "" "${tmp_dir}/delete.json"
delete_operation="$(json_get "${tmp_dir}/delete.json" "workspaceOperation.operationId")"
poll_operation "${WORKSPACE_ID}" "${delete_operation}" "${tmp_dir}/delete-operation.json"

echo "Workspace runner deployed E2E passed for ${WORKSPACE_ID}."
