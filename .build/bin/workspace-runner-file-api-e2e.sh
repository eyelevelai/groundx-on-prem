#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPT_VERSION="workspace-runner-file-api-e2e-v2"

NAMESPACE="${NAMESPACE:-eyelevel}"
WORKSPACE_SERVICE="${WORKSPACE_SERVICE:-workspace-api}"
WORKSPACE_SERVICE_PORT="${WORKSPACE_SERVICE_PORT:-80}"
LOCAL_PORT="${LOCAL_PORT:-18080}"
BASE_URL="http://127.0.0.1:${LOCAL_PORT}"

WORKSPACE_SECRET="${WORKSPACE_SECRET:-workspace-secret}"
PARTNER_USERNAME="${PARTNER_USERNAME:-${PARTNER_API_KEY:-workspace-file-e2e-partner}}"
CUSTOMER_USERNAME="${CUSTOMER_USERNAME:-${PARTNER_USERNAME}}"
WRONG_PARTNER_USERNAME="${WRONG_PARTNER_USERNAME:-workspace-file-e2e-wrong-partner}"
PROJECT_ID="${PROJECT_ID:-workspace-file-e2e-project}"
PROJECT_NAME="${PROJECT_NAME:-Workspace Runner File API E2E Project}"
PROJECT_TYPE="${PROJECT_TYPE:-web-ui}"
SCAFFOLD_REPOSITORY_URL="${SCAFFOLD_REPOSITORY_URL:-${REPOSITORY_URL:-https://github.com/GroundX-Studio/groundx-web-ui-scaffold}}"
SCAFFOLD_REF="${SCAFFOLD_REF:-main}"
E2E_FILE_PATH="${E2E_FILE_PATH:-workspace-runner-file-api-e2e.txt}"
STATE_FILE="${STATE_FILE:-${REPO_ROOT}/.workspace-runner-file-api-e2e-state.json}"
RUN_CREATE_FLOW="${RUN_CREATE_FLOW:-true}"
RUN_DELETE_FILE="${RUN_DELETE_FILE:-true}"
RUN_PROJECT_CLEANUP="${RUN_PROJECT_CLEANUP:-true}"
POLL_TIMEOUT_SECONDS="${POLL_TIMEOUT_SECONDS:-300}"
PROJECT_CREATED=false
CLEANUP_COMPLETED=false

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

if [[ "${RUN_CREATE_FLOW}" != "true" && -f "${STATE_FILE}" ]]; then
  PROJECT_ID="$(python - "$STATE_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle).get("projectId", ""))
PY
)"
fi

tmp_dir="$(mktemp -d)"

cleanup() {
  local exit_code=$?
  trap - EXIT
  set +e
  rm -rf "${tmp_dir}"
  exit "${exit_code}"
}
trap cleanup EXIT
trap 'echo "Workspace runner file API E2E failed at line ${LINENO}: ${BASH_COMMAND}" >&2' ERR

json_get() {
  local file="$1"
  local expr="$2"
  python - "$file" "$expr" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    value = json.load(handle)
for part in sys.argv[2].split("."):
    if part:
        value = value[part]
print(value)
PY
}

require_response_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -q "${expected}" "${file}"; then
    echo "Expected response to contain: ${expected}" >&2
    cat "${file}" >&2 || true
    exit 1
  fi
}

api() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local output="$4"
  local status
  status="$(api_status "${method}" "${path}" "${body}" "${output}")"
  if (( status < 200 || status > 299 )); then
    echo "${method} ${path} returned HTTP ${status}" >&2
    cat "${output}" >&2 || true
    exit 1
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

poll_operation() {
  local operation_id="$1"
  local output="$2"
  local deadline=$((SECONDS + POLL_TIMEOUT_SECONDS))
  local status=""
  local message=""
  while (( SECONDS < deadline )); do
    api GET "/operations/${operation_id}" "" "${output}"
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

wait_for_project_purge() {
  local deadline=$((SECONDS + POLL_TIMEOUT_SECONDS))
  local project_status=""
  while (( SECONDS < deadline )); do
    project_status="$(api_status GET "/projects/${PROJECT_ID}" "" "${tmp_dir}/project-after-cleanup.json")"
    if [[ "${project_status}" == "404" ]]; then
      return 0
    fi
    sleep 2
  done
  echo "Expected project record to be purged, got HTTP ${project_status}" >&2
  cat "${tmp_dir}/project-after-cleanup.json" >&2
  return 1
}

workspace_api_reachable() {
  curl -fsS "${BASE_URL}/health" >/dev/null 2>&1
}

require_existing_port_forward() {
  if workspace_api_reachable; then
    echo "Using existing workspace API at ${BASE_URL}"
    return 0
  fi
  echo "Workspace API is not reachable at ${BASE_URL}." >&2
  echo "Start a port-forward first, for example:" >&2
  echo "  kubectl -n ${NAMESPACE} port-forward svc/${WORKSPACE_SERVICE} ${LOCAL_PORT}:${WORKSPACE_SERVICE_PORT}" >&2
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

project_patch_body() {
  local file_path="$1"
  python - "$PARTNER_USERNAME" "$CUSTOMER_USERNAME" "$file_path" <<'PY'
import json
import sys

partner_username, customer_username, file_path = sys.argv[1:]
patch = "\n".join([
    f"diff --git a/{file_path} b/{file_path}",
    f"--- a/{file_path}",
    f"+++ b/{file_path}",
    "@@ -1 +1,2 @@",
    "-created by workspace runner file api e2e",
    "+created by workspace runner file api e2e",
    "+edited by workspace runner file api e2e",
    "",
])
print(json.dumps({
    "partnerUsername": partner_username,
    "username": customer_username,
    "workspace": {"patch": patch},
}))
PY
}

project_delete_file_body() {
  local file_path="$1"
  python - "$PARTNER_USERNAME" "$CUSTOMER_USERNAME" "$file_path" <<'PY'
import json
import sys

partner_username, customer_username, file_path = sys.argv[1:]
patch = "\n".join([
    f"diff --git a/{file_path} b/{file_path}",
    "deleted file mode 100644",
    f"--- a/{file_path}",
    "+++ /dev/null",
    "@@ -1,2 +0,0 @@",
    "-created by workspace runner file api e2e",
    "-edited by workspace runner file api e2e",
    "",
])
print(json.dumps({
    "partnerUsername": partner_username,
    "username": customer_username,
    "workspace": {"patch": patch},
}))
PY
}

write_state() {
  python - "$STATE_FILE" "$PROJECT_ID" <<'PY'
import json
import sys

with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump({"projectId": sys.argv[2]}, handle, indent=2)
    handle.write("\n")
PY
}

verify_project_cache_absent() {
  local leftover
  leftover="$(
    kubectl -n "${NAMESPACE}" exec "deploy/${WORKSPACE_SERVICE}" -- sh -lc \
      "find /tmp/workspaces -maxdepth 1 -mindepth 1 -type d -name 'workspace-${PROJECT_ID}-*' -print" 2>/dev/null || true
  )"
  if [[ -n "${leftover}" ]]; then
    echo "Project cache directories still exist after cleanup:" >&2
    echo "${leftover}" >&2
    return 1
  fi
}

cleanup_project() {
  echo "Deleting project cache, managed repo, and database records for ${PROJECT_ID}"
  local delete_status
  delete_status="$(api_status DELETE "/projects/${PROJECT_ID}?purge=true&deleteRepository=true" "" "${tmp_dir}/delete-project.json")"
  if [[ "${delete_status}" != "200" && "${delete_status}" != "404" ]]; then
    echo "DELETE /projects/${PROJECT_ID} returned HTTP ${delete_status}" >&2
    cat "${tmp_dir}/delete-project.json" >&2 || true
    return 1
  fi
  wait_for_project_purge
  verify_project_cache_absent
  rm -f "${STATE_FILE}"
  CLEANUP_COMPLETED=true
}

echo "Checking workspace runner rollout before file API E2E"
echo "Using ${SCRIPT_VERSION}"
kubectl -n "${NAMESPACE}" rollout status "deployment/${WORKSPACE_SERVICE}" --timeout=180s
for worker in provision workspace cleanup; do
  kubectl -n "${NAMESPACE}" rollout status "deployment/workspace-${worker}" --timeout=180s
done

require_existing_port_forward

echo "Fetching storage status"
api GET /storage "" "${tmp_dir}/storage.json"

echo "Checking workspace runner cleanup capabilities"
api GET /capabilities "" "${tmp_dir}/capabilities.json"
if [[ "$(json_get "${tmp_dir}/capabilities.json" "capabilities.deleteProject")" != "True" ]]; then
  echo "Workspace runner does not report deleteProject capability. Rebuild and redeploy workspace-runner before running this E2E." >&2
  cat "${tmp_dir}/capabilities.json" >&2
  exit 1
fi

if [[ "${RUN_CREATE_FLOW}" == "true" ]]; then
  echo "Creating project ${PROJECT_ID}"
  project_body="$(
    envelope "{\"projectId\":\"${PROJECT_ID}\",\"projectName\":\"${PROJECT_NAME}\",\"projectType\":\"${PROJECT_TYPE}\",\"scaffold\":{\"repositoryUrl\":\"${SCAFFOLD_REPOSITORY_URL}\",\"ref\":\"${SCAFFOLD_REF}\"}}"
  )"
  api POST /projects "${project_body}" "${tmp_dir}/project.json"
  project_operation="$(json_get "${tmp_dir}/project.json" "workspaceOperation.operationId")"
  poll_operation "${project_operation}" "${tmp_dir}/project-operation.json"
  write_state
  PROJECT_CREATED=true

  echo "Writing ${E2E_FILE_PATH}"
  write_body="$(envelope "{\"filePath\":\"${E2E_FILE_PATH}\",\"content\":\"created by workspace runner file api e2e\\n\"}")"
  api POST "/projects/${PROJECT_ID}/files/write" "${write_body}" "${tmp_dir}/write.json"
  write_operation="$(json_get "${tmp_dir}/write.json" "workspaceOperation.operationId")"
  poll_operation "${write_operation}" "${tmp_dir}/write-operation.json"

  echo "Reading ${E2E_FILE_PATH}"
  read_body="$(envelope "{\"filePath\":\"${E2E_FILE_PATH}\"}")"
  api POST "/projects/${PROJECT_ID}/files/read" "${read_body}" "${tmp_dir}/read.json"
  require_response_contains "${tmp_dir}/read.json" "created by workspace runner file api e2e"

  echo "Editing ${E2E_FILE_PATH} via project patch API"
  patch_body="$(project_patch_body "${E2E_FILE_PATH}")"
  api POST "/projects/${PROJECT_ID}/patches" "${patch_body}" "${tmp_dir}/patch.json"
  patch_operation="$(json_get "${tmp_dir}/patch.json" "workspaceOperation.operationId")"
  poll_operation "${patch_operation}" "${tmp_dir}/patch-operation.json"

  echo "Reading edited ${E2E_FILE_PATH}"
  api POST "/projects/${PROJECT_ID}/files/read" "${read_body}" "${tmp_dir}/edited-read.json"
  require_response_contains "${tmp_dir}/edited-read.json" "created by workspace runner file api e2e"
  require_response_contains "${tmp_dir}/edited-read.json" "edited by workspace runner file api e2e"

  echo "Checking project diff"
  api GET "/projects/${PROJECT_ID}/diff" "" "${tmp_dir}/diff.json"
  require_response_contains "${tmp_dir}/diff.json" '"diff"'

  if [[ "${RUN_DELETE_FILE}" == "true" ]]; then
    echo "Deleting ${E2E_FILE_PATH} via project patch API"
    delete_file_body="$(project_delete_file_body "${E2E_FILE_PATH}")"
    api POST "/projects/${PROJECT_ID}/patches" "${delete_file_body}" "${tmp_dir}/delete-file.json"
    delete_file_operation="$(json_get "${tmp_dir}/delete-file.json" "workspaceOperation.operationId")"
    poll_operation "${delete_file_operation}" "${tmp_dir}/delete-file-operation.json"
    require_response_contains "${tmp_dir}/delete-file-operation.json" '"deletedFiles"'
    require_response_contains "${tmp_dir}/delete-file-operation.json" "${E2E_FILE_PATH}"

    echo "Verifying ${E2E_FILE_PATH} was deleted"
    missing_read_status="$(api_status POST "/projects/${PROJECT_ID}/files/read" "${read_body}" "${tmp_dir}/missing-read.json")"
    if [[ "${missing_read_status}" != "404" ]]; then
      echo "Expected deleted file read to return 404, got ${missing_read_status}" >&2
      cat "${tmp_dir}/missing-read.json" >&2
      exit 1
    fi
  else
    echo "Skipping file delete because RUN_DELETE_FILE=${RUN_DELETE_FILE}."
  fi

  echo "Checking wrong-owner rejection"
  wrong_status="$(api_status GET "/projects/${PROJECT_ID}" "" "${tmp_dir}/wrong-owner.json" "${WRONG_PARTNER_USERNAME}")"
  if [[ "${wrong_status}" != "403" ]]; then
    echo "Expected wrong-owner project request to return 403, got ${wrong_status}" >&2
    cat "${tmp_dir}/wrong-owner.json" >&2
    exit 1
  fi
else
  echo "Skipping create/edit flow because RUN_CREATE_FLOW=${RUN_CREATE_FLOW}."
fi

if [[ "${RUN_PROJECT_CLEANUP}" == "true" ]]; then
  cleanup_project
else
  echo "Skipping project cleanup because RUN_PROJECT_CLEANUP=${RUN_PROJECT_CLEANUP}."
fi

echo "Workspace runner project file API E2E passed for ${PROJECT_ID}."
