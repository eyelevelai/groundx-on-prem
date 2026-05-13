#!/usr/bin/env bash
set -euo pipefail

SCRIPT_VERSION="workspace-runner-e2e-full-cleanup-v2"

NAMESPACE="${NAMESPACE:-eyelevel}"
WORKSPACE_SERVICE="${WORKSPACE_SERVICE:-workspace-api}"
WORKSPACE_SERVICE_PORT="${WORKSPACE_SERVICE_PORT:-80}"
LOCAL_PORT="${LOCAL_PORT:-18080}"
BASE_URL="http://127.0.0.1:${LOCAL_PORT}"

WORKSPACE_SECRET="${WORKSPACE_SECRET:-workspace-secret}"
PARTNER_USERNAME="${PARTNER_USERNAME:-workspace-e2e-partner}"
CUSTOMER_USERNAME="${CUSTOMER_USERNAME:-workspace-e2e-customer}"
WRONG_PARTNER_USERNAME="${WRONG_PARTNER_USERNAME:-workspace-e2e-wrong-partner}"
PROJECT_ID="${PROJECT_ID:-workspace-e2e-project}"
WORKSPACE_ID="${WORKSPACE_ID:-workspace-e2e-$(date +%s)}"
BRANCH="${BRANCH:-workspace-e2e-$(date +%s)}"
E2E_FILE_PATH="${E2E_FILE_PATH:-workspace-e2e.txt}"
RUN_PUBLISH="${RUN_PUBLISH:-false}"
RUN_DELETE_FILE="${RUN_DELETE_FILE:-true}"
RUN_WORKSPACE_CLEANUP="${RUN_WORKSPACE_CLEANUP:-true}"
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
workspace_cleanup_requested="false"
workspace_cleaned_up="false"

cleanup() {
  local exit_code=$?
  trap - EXIT
  set +e
  if [[ "${RUN_WORKSPACE_CLEANUP}" == "true" ]]; then
    cleanup_workspace_cache false
  else
    echo "Skipping workspace cache cleanup because RUN_WORKSPACE_CLEANUP=${RUN_WORKSPACE_CLEANUP}."
  fi
  if [[ -n "${port_forward_pid}" ]]; then
    kill "${port_forward_pid}" >/dev/null 2>&1 || true
    wait "${port_forward_pid}" >/dev/null 2>&1 || true
  fi
  rm -rf "${tmp_dir}"
  exit "${exit_code}"
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

workspace_api_reachable() {
  curl -fsS "${BASE_URL}/health" >/dev/null 2>&1
}

start_port_forward() {
  if workspace_api_reachable; then
    return 0
  fi
  if [[ -n "${port_forward_pid}" ]] && kill -0 "${port_forward_pid}" >/dev/null 2>&1; then
    return 0
  fi

  echo "Opening port-forward to service/${WORKSPACE_SERVICE} on ${BASE_URL}"
  kubectl -n "${NAMESPACE}" port-forward "service/${WORKSPACE_SERVICE}" \
    --address 127.0.0.1 "${LOCAL_PORT}:${WORKSPACE_SERVICE_PORT}" \
    >"${tmp_dir}/port-forward.log" 2>&1 &
  port_forward_pid="$!"

  for _ in {1..30}; do
    if workspace_api_reachable; then
      break
    fi
    sleep 1
  done
  workspace_api_reachable
}

cleanup_workspace_cache() {
  local strict="${1:-false}"
  if [[ "${workspace_cleaned_up}" == "true" ]]; then
    return 0
  fi
  if [[ "${workspace_cleanup_requested}" != "true" ]]; then
    echo "Workspace cleanup not requested yet for ${WORKSPACE_ID}; skipping cleanup."
    return 0
  fi
  if [[ -z "${WORKSPACE_RUNNER_TOKEN:-}" ]]; then
    echo "Workspace cleanup cannot run because WORKSPACE_RUNNER_TOKEN is empty." >&2
    [[ "${strict}" == "true" ]] && return 1
    return 0
  fi
  if ! workspace_api_reachable; then
    if [[ -n "${port_forward_pid}" ]] && ! kill -0 "${port_forward_pid}" >/dev/null 2>&1; then
      echo "Workspace API port-forward process ${port_forward_pid} is not running; restarting it." >&2
    else
      echo "Workspace API is not reachable; opening port-forward." >&2
    fi
    if [[ "${strict}" == "true" ]]; then
      start_port_forward
    fi
  fi
  if ! workspace_api_reachable; then
    echo "Workspace cleanup cannot run because the workspace API is unavailable." >&2
    [[ "${strict}" == "true" ]] && return 1
    return 0
  fi

  echo "Cleaning up workspace cache and records for ${WORKSPACE_ID}"
  local delete_response="${tmp_dir}/delete-on-exit.json"
  local delete_status
  delete_status="$(api_status DELETE "/workspaces/${WORKSPACE_ID}?purge=true&deleteProject=true" "" "${delete_response}")"
  if [[ "${delete_status}" != "200" ]]; then
    echo "Workspace cleanup request returned HTTP ${delete_status}; continuing test cleanup." >&2
    cat "${delete_response}" >&2 || true
    return 1
  fi

  local delete_operation
  delete_operation="$(json_get "${delete_response}" "workspaceOperation.operationId" 2>/dev/null || true)"
  if [[ -z "${delete_operation}" ]]; then
    return 1
  fi
  if poll_operation "${WORKSPACE_ID}" "${delete_operation}" "${tmp_dir}/delete-on-exit-operation.json"; then
    if [[ "$(json_get "${tmp_dir}/delete-on-exit-operation.json" "workspaceOperation.result.status")" != "deleted" ]]; then
      echo "Workspace cleanup operation did not report deleted status." >&2
      cat "${tmp_dir}/delete-on-exit-operation.json" >&2
      return 1
    fi
    if [[ "$(json_get "${tmp_dir}/delete-on-exit-operation.json" "workspaceOperation.result.cacheDeleted")" != "True" ]]; then
      echo "Workspace cleanup operation did not delete the cache path." >&2
      cat "${tmp_dir}/delete-on-exit-operation.json" >&2
      return 1
    fi
    if [[ "$(json_get "${tmp_dir}/delete-on-exit-operation.json" "workspaceOperation.result.workspaceDeleted")" != "True" ]]; then
      echo "Workspace cleanup operation did not purge the workspace record." >&2
      cat "${tmp_dir}/delete-on-exit-operation.json" >&2
      return 1
    fi
    if [[ "$(json_get "${tmp_dir}/delete-on-exit-operation.json" "workspaceOperation.result.projectDeleted")" != "True" ]]; then
      echo "Workspace cleanup operation did not purge the project record." >&2
      cat "${tmp_dir}/delete-on-exit-operation.json" >&2
      return 1
    fi
    if [[ "${RUN_PUBLISH}" == "true" ]] && [[ -f "${tmp_dir}/publish-operation.json" ]] && [[ "$(json_get "${tmp_dir}/publish-operation.json" "workspaceOperation.result.dryRun")" == "False" ]]; then
      if [[ "$(json_get "${tmp_dir}/delete-on-exit-operation.json" "workspaceOperation.result.managedRepositoryDeleted")" != "True" ]]; then
        echo "Workspace cleanup operation did not delete the managed repository." >&2
        cat "${tmp_dir}/delete-on-exit-operation.json" >&2
        return 1
      fi
    fi
    verify_workspace_cache_absent
    verify_workspace_records_absent
    workspace_cleaned_up="true"
  else
    echo "Workspace cleanup operation did not succeed; continuing test cleanup." >&2
    return 1
  fi
}

verify_workspace_cache_absent() {
  local leftover
  leftover="$(
    kubectl -n "${NAMESPACE}" exec "deploy/${WORKSPACE_SERVICE}" -- sh -lc \
      "find /tmp/workspaces -maxdepth 1 -mindepth 1 -type d \\( -name '${WORKSPACE_ID}-*' -o -name 'workspace-${PROJECT_ID}-*' \\) -print" 2>/dev/null || true
  )"
  if [[ -n "${leftover}" ]]; then
    echo "Workspace cache directories still exist after cleanup:" >&2
    echo "${leftover}" >&2
    return 1
  fi
}

verify_workspace_records_absent() {
  local workspace_status
  local project_status
  workspace_status="$(api_status GET "/workspaces/${WORKSPACE_ID}" "" "${tmp_dir}/workspace-after-cleanup.json")"
  project_status="$(api_status GET "/projects/${PROJECT_ID}" "" "${tmp_dir}/project-after-cleanup.json")"
  if [[ "${workspace_status}" != "404" ]]; then
    echo "Expected workspace record to be purged, got HTTP ${workspace_status}" >&2
    cat "${tmp_dir}/workspace-after-cleanup.json" >&2
    return 1
  fi
  if [[ "${project_status}" != "404" ]]; then
    echo "Expected project record to be purged, got HTTP ${project_status}" >&2
    cat "${tmp_dir}/project-after-cleanup.json" >&2
    return 1
  fi
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

delete_file_envelope() {
  local file_path="$1"
  local created_content="$2"
  local edited_content="$3"
  python - "$PARTNER_USERNAME" "$CUSTOMER_USERNAME" "$file_path" "$created_content" "$edited_content" <<'PY'
import json
import sys

partner_username = sys.argv[1]
customer_username = sys.argv[2]
file_path = sys.argv[3]
created_content = sys.argv[4]
edited_content = sys.argv[5]
patch = "\n".join([
    f"diff --git a/{file_path} b/{file_path}",
    "deleted file mode 100644",
    f"--- a/{file_path}",
    "+++ /dev/null",
    "@@ -1,2 +0,0 @@",
    f"-{created_content}",
    f"-{edited_content}",
    "",
])
print(json.dumps({
    "partnerUsername": partner_username,
    "username": customer_username,
    "workspace": {"patch": patch},
}))
PY
}

edit_file_envelope() {
  local file_path="$1"
  local original_content="$2"
  local edited_content="$3"
  python - "$PARTNER_USERNAME" "$CUSTOMER_USERNAME" "$file_path" "$original_content" "$edited_content" <<'PY'
import json
import sys

partner_username = sys.argv[1]
customer_username = sys.argv[2]
file_path = sys.argv[3]
original_content = sys.argv[4]
edited_content = sys.argv[5]
patch = "\n".join([
    f"diff --git a/{file_path} b/{file_path}",
    f"--- a/{file_path}",
    f"+++ b/{file_path}",
    "@@ -1 +1,2 @@",
    f"-{original_content}",
    f"+{original_content}",
    f"+{edited_content}",
    "",
])
print(json.dumps({
    "partnerUsername": partner_username,
    "username": customer_username,
    "workspace": {"patch": patch},
}))
PY
}

echo "Checking workspace runner rollout before E2E"
echo "Using ${SCRIPT_VERSION}"
kubectl -n "${NAMESPACE}" rollout status "deployment/${WORKSPACE_SERVICE}" --timeout=180s
for worker in provision workspace command publish cleanup; do
  kubectl -n "${NAMESPACE}" rollout status "deployment/workspace-${worker}" --timeout=180s
done

start_port_forward

echo "Fetching storage status"
api GET /storage "" "${tmp_dir}/storage.json"

echo "Checking workspace runner cleanup capabilities"
api GET /capabilities "" "${tmp_dir}/capabilities.json"
if [[ "$(json_get "${tmp_dir}/capabilities.json" "capabilities.cleanupPurge")" != "True" ]]; then
  echo "Workspace runner does not report cleanupPurge capability. Rebuild and redeploy workspace-runner before running this E2E." >&2
  cat "${tmp_dir}/capabilities.json" >&2
  exit 1
fi
if [[ "$(json_get "${tmp_dir}/capabilities.json" "capabilities.deleteProject")" != "True" ]]; then
  echo "Workspace runner does not report deleteProject capability. Rebuild and redeploy workspace-runner before running this E2E." >&2
  cat "${tmp_dir}/capabilities.json" >&2
  exit 1
fi

echo "Creating project ${PROJECT_ID}"
project_body="$(envelope "{\"projectId\":\"${PROJECT_ID}\",\"repository\":{\"url\":\"${REPOSITORY_URL}\"}}")"
api POST /projects "${project_body}" "${tmp_dir}/project.json"
project_operation="$(json_get "${tmp_dir}/project.json" "workspaceOperation.operationId")"
poll_operation "" "${project_operation}" "${tmp_dir}/project-operation.json"

echo "Creating workspace ${WORKSPACE_ID} from ${REPOSITORY_URL}"
workspace_body="$(envelope "{\"projectId\":\"${PROJECT_ID}\",\"workspaceId\":\"${WORKSPACE_ID}\",\"branch\":\"${BRANCH}\",\"repository\":{\"url\":\"${REPOSITORY_URL}\"}}")"
api POST /workspaces "${workspace_body}" "${tmp_dir}/workspace.json"
workspace_operation="$(json_get "${tmp_dir}/workspace.json" "workspaceOperation.operationId")"
workspace_cleanup_requested="true"
poll_operation "${WORKSPACE_ID}" "${workspace_operation}" "${tmp_dir}/workspace-operation.json"

echo "Writing ${E2E_FILE_PATH}"
e2e_file_content="workspace runner e2e ${WORKSPACE_ID}"
edited_file_content="workspace runner e2e ${WORKSPACE_ID} edited"
write_body="$(envelope "{\"filePath\":\"${E2E_FILE_PATH}\",\"content\":\"${e2e_file_content}\\n\"}")"
api POST "/workspaces/${WORKSPACE_ID}/files/write" "${write_body}" "${tmp_dir}/write.json"
write_operation="$(json_get "${tmp_dir}/write.json" "workspaceOperation.operationId")"
poll_operation "${WORKSPACE_ID}" "${write_operation}" "${tmp_dir}/write-operation.json"

echo "Reading ${E2E_FILE_PATH}"
read_body="$(envelope "{\"filePath\":\"${E2E_FILE_PATH}\"}")"
api POST "/workspaces/${WORKSPACE_ID}/files/read" "${read_body}" "${tmp_dir}/read.json"
grep -q "workspace runner e2e ${WORKSPACE_ID}" "${tmp_dir}/read.json"

echo "Editing ${E2E_FILE_PATH} via patch"
edit_file_body="$(edit_file_envelope "${E2E_FILE_PATH}" "${e2e_file_content}" "${edited_file_content}")"
api POST "/workspaces/${WORKSPACE_ID}/patches" "${edit_file_body}" "${tmp_dir}/edit-file.json"
edit_file_operation="$(json_get "${tmp_dir}/edit-file.json" "workspaceOperation.operationId")"
poll_operation "${WORKSPACE_ID}" "${edit_file_operation}" "${tmp_dir}/edit-file-operation.json"

echo "Reading edited ${E2E_FILE_PATH}"
api POST "/workspaces/${WORKSPACE_ID}/files/read" "${read_body}" "${tmp_dir}/edited-read.json"
grep -q "${e2e_file_content}" "${tmp_dir}/edited-read.json"
grep -q "${edited_file_content}" "${tmp_dir}/edited-read.json"

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

if [[ "${RUN_DELETE_FILE}" == "true" ]]; then
  echo "Deleting ${E2E_FILE_PATH} via patch"
  delete_file_body="$(delete_file_envelope "${E2E_FILE_PATH}" "${e2e_file_content}" "${edited_file_content}")"
  api POST "/workspaces/${WORKSPACE_ID}/patches" "${delete_file_body}" "${tmp_dir}/delete-file.json"
  delete_file_operation="$(json_get "${tmp_dir}/delete-file.json" "workspaceOperation.operationId")"
  poll_operation "${WORKSPACE_ID}" "${delete_file_operation}" "${tmp_dir}/delete-file-operation.json"
  grep -q '"deletedFiles"' "${tmp_dir}/delete-file-operation.json"
  grep -q "${E2E_FILE_PATH}" "${tmp_dir}/delete-file-operation.json"

  echo "Verifying ${E2E_FILE_PATH} was deleted"
  missing_read_status="$(api_status POST "/workspaces/${WORKSPACE_ID}/files/read" "${read_body}" "${tmp_dir}/missing-read.json")"
  if [[ "${missing_read_status}" != "404" ]]; then
    echo "Expected deleted file read to return 404, got ${missing_read_status}" >&2
    cat "${tmp_dir}/missing-read.json" >&2
    exit 1
  fi
  grep -q "workspace file not found" "${tmp_dir}/missing-read.json"
else
  echo "Skipping file delete because RUN_DELETE_FILE=${RUN_DELETE_FILE}."
fi

echo "Checking wrong-owner rejection"
wrong_status="$(api_status GET "/workspaces/${WORKSPACE_ID}" "" "${tmp_dir}/wrong-owner.json" "${WRONG_PARTNER_USERNAME}")"
if [[ "${wrong_status}" != "403" ]]; then
  echo "Expected wrong-owner request to return 403, got ${wrong_status}" >&2
  cat "${tmp_dir}/wrong-owner.json" >&2
  exit 1
fi

if [[ "${RUN_PUBLISH}" == "true" ]]; then
  echo "Running publish operation. This triggers configured publish when publish_dry_run is false."
  publish_body="$(envelope "{\"publish\":{\"title\":\"Workspace E2E ${WORKSPACE_ID}\",\"description\":\"Automated workspace runner E2E\",\"draft\":true}}")"
  api POST "/workspaces/${WORKSPACE_ID}/publish" "${publish_body}" "${tmp_dir}/publish.json"
  publish_operation="$(json_get "${tmp_dir}/publish.json" "workspaceOperation.operationId")"
  poll_operation "${WORKSPACE_ID}" "${publish_operation}" "${tmp_dir}/publish-operation.json"
else
  echo "Skipping publish. Set RUN_PUBLISH=true to exercise /publish."
fi

if [[ "${RUN_WORKSPACE_CLEANUP}" == "true" ]]; then
  echo "Deleting workspace cache and database records"
  cleanup_workspace_cache true
else
  echo "Skipping workspace cache cleanup because RUN_WORKSPACE_CLEANUP=${RUN_WORKSPACE_CLEANUP}."
fi

echo "Workspace runner deployed E2E passed for ${WORKSPACE_ID}."
