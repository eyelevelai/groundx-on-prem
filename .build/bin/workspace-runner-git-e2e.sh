#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPT_VERSION="workspace-runner-git-e2e-v1"

NAMESPACE="${NAMESPACE:-eyelevel}"
WORKSPACE_SERVICE="${WORKSPACE_SERVICE:-workspace-api}"
WORKSPACE_SERVICE_PORT="${WORKSPACE_SERVICE_PORT:-80}"
LOCAL_PORT="${LOCAL_PORT:-18080}"
BASE_URL="http://127.0.0.1:${LOCAL_PORT}"

WORKSPACE_SECRET="${WORKSPACE_SECRET:-workspace-secret}"
PARTNER_USERNAME="${PARTNER_USERNAME:-${PARTNER_API_KEY:-workspace-git-e2e-partner}}"
CUSTOMER_USERNAME="${CUSTOMER_USERNAME:-${PARTNER_USERNAME}}"
WRONG_PARTNER_USERNAME="${WRONG_PARTNER_USERNAME:-workspace-git-e2e-wrong-partner}"
PROJECT_ID="${PROJECT_ID:-workspace-git-e2e-project}"
PROJECT_NAME="${PROJECT_NAME:-Workspace Runner Git E2E Project}"
PROJECT_TYPE="${PROJECT_TYPE:-web-ui}"
SCAFFOLD_REPOSITORY_URL="${SCAFFOLD_REPOSITORY_URL:-${REPOSITORY_URL:-https://github.com/GroundX-Studio/groundx-web-ui-scaffold}}"
SCAFFOLD_REF="${SCAFFOLD_REF:-main}"
E2E_FILE_PATH="${E2E_FILE_PATH:-workspace-runner-git-e2e.txt}"
STATE_FILE="${STATE_FILE:-${REPO_ROOT}/.workspace-runner-git-e2e-state.json}"
RUN_CREATE_FLOW="${RUN_CREATE_FLOW:-true}"
RUN_PUBLISH="${RUN_PUBLISH:-true}"
RUN_PROJECT_CLEANUP="${RUN_PROJECT_CLEANUP:-true}"
POLL_TIMEOUT_SECONDS="${POLL_TIMEOUT_SECONDS:-300}"

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

cleanup() {
  local exit_code=$?
  trap - EXIT
  set +e
  rm -rf "${tmp_dir}"
  exit "${exit_code}"
}
trap cleanup EXIT
trap 'echo "Workspace runner project/git E2E failed at line ${LINENO}: ${BASH_COMMAND}" >&2' ERR

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
  echo "Deleting project ${PROJECT_ID}, managed repo, and test records"
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
}

require_git() {
  if ! command -v git >/dev/null 2>&1; then
    echo "git is required for workspace-runner-git-e2e.sh." >&2
    exit 1
  fi
}

if [[ "${RUN_CREATE_FLOW}" != "true" && -f "${STATE_FILE}" ]]; then
  PROJECT_ID="$(python - "$STATE_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle).get("projectId", ""))
PY
)"
fi

echo "Checking workspace runner rollout before project/git E2E"
echo "Using ${SCRIPT_VERSION}"
kubectl -n "${NAMESPACE}" rollout status "deployment/${WORKSPACE_SERVICE}" --timeout=180s
for worker in provision publish cleanup; do
  kubectl -n "${NAMESPACE}" rollout status "deployment/workspace-${worker}" --timeout=180s
done

require_existing_port_forward

echo "Checking workspace runner capabilities"
api GET /capabilities "" "${tmp_dir}/capabilities.json"
if [[ "$(json_get "${tmp_dir}/capabilities.json" "capabilities.deleteProject")" != "True" ]]; then
  echo "Workspace runner does not report deleteProject capability. Rebuild and redeploy workspace-runner before running this E2E." >&2
  cat "${tmp_dir}/capabilities.json" >&2
  exit 1
fi

if [[ "${RUN_CREATE_FLOW}" == "true" ]]; then
  require_git

  echo "Creating project ${PROJECT_ID} from scaffold ${SCAFFOLD_REPOSITORY_URL}"
  project_body="$(
    envelope "{\"projectId\":\"${PROJECT_ID}\",\"projectName\":\"${PROJECT_NAME}\",\"projectType\":\"${PROJECT_TYPE}\",\"scaffold\":{\"repositoryUrl\":\"${SCAFFOLD_REPOSITORY_URL}\",\"ref\":\"${SCAFFOLD_REF}\"}}"
  )"
  api POST /projects "${project_body}" "${tmp_dir}/project.json"
  project_operation="$(json_get "${tmp_dir}/project.json" "workspaceOperation.operationId")"
  poll_operation "${project_operation}" "${tmp_dir}/project-operation.json"

  echo "Requesting git session"
  api POST "/projects/${PROJECT_ID}/git-session" "$(envelope "{}")" "${tmp_dir}/git-session.json"
  repository_url="$(json_get "${tmp_dir}/git-session.json" "gitSession.repositoryUrl")"
  branch="$(json_get "${tmp_dir}/git-session.json" "gitSession.branch")"
  username="$(json_get "${tmp_dir}/git-session.json" "gitSession.username")"
  password="$(json_get "${tmp_dir}/git-session.json" "gitSession.password")"
  printf '%s' "${username}" >"${tmp_dir}/git-username"
  printf '%s' "${password}" >"${tmp_dir}/git-password"

  cat >"${tmp_dir}/askpass.sh" <<'EOF'
#!/usr/bin/env sh
case "$1" in
  *Username*) cat "${GIT_SESSION_USERNAME_FILE}" ;;
  *) cat "${GIT_SESSION_PASSWORD_FILE}" ;;
esac
EOF
  chmod 700 "${tmp_dir}/askpass.sh"

  clone_dir="${tmp_dir}/managed-repo"
  echo "Cloning managed repo"
  GIT_TERMINAL_PROMPT=0 \
    GIT_ASKPASS="${tmp_dir}/askpass.sh" \
    GIT_SESSION_USERNAME_FILE="${tmp_dir}/git-username" \
    GIT_SESSION_PASSWORD_FILE="${tmp_dir}/git-password" \
    git -c credential.helper= clone "${repository_url}" "${clone_dir}" >/dev/null
  git -C "${clone_dir}" checkout "${branch}" >/dev/null

  echo "Creating, editing, and deleting ${E2E_FILE_PATH} locally"
  printf "created by workspace runner git e2e\n" >"${clone_dir}/${E2E_FILE_PATH}"
  git -C "${clone_dir}" add "${E2E_FILE_PATH}"
  git -C "${clone_dir}" commit -m "Create ${E2E_FILE_PATH}" >/dev/null
  printf "created by workspace runner git e2e\nedited by workspace runner git e2e\n" >"${clone_dir}/${E2E_FILE_PATH}"
  git -C "${clone_dir}" add "${E2E_FILE_PATH}"
  git -C "${clone_dir}" commit -m "Edit ${E2E_FILE_PATH}" >/dev/null
  rm "${clone_dir}/${E2E_FILE_PATH}"
  git -C "${clone_dir}" add "${E2E_FILE_PATH}"
  git -C "${clone_dir}" commit -m "Delete ${E2E_FILE_PATH}" >/dev/null
  GIT_TERMINAL_PROMPT=0 \
    GIT_ASKPASS="${tmp_dir}/askpass.sh" \
    GIT_SESSION_USERNAME_FILE="${tmp_dir}/git-username" \
    GIT_SESSION_PASSWORD_FILE="${tmp_dir}/git-password" \
    git -c credential.helper= -C "${clone_dir}" push origin "${branch}" >/dev/null
  commit_sha="$(git -C "${clone_dir}" rev-parse HEAD)"

  python - "$STATE_FILE" "$PROJECT_ID" "$repository_url" "$branch" "$commit_sha" <<'PY'
import json
import sys

path, project_id, repository_url, branch, commit_sha = sys.argv[1:]
with open(path, "w", encoding="utf-8") as handle:
    json.dump(
        {"projectId": project_id, "repositoryUrl": repository_url, "branch": branch, "commitSha": commit_sha},
        handle,
        indent=2,
    )
    handle.write("\n")
PY

  echo "Checking wrong-owner rejection"
  wrong_status="$(api_status GET "/projects/${PROJECT_ID}" "" "${tmp_dir}/wrong-owner.json" "${WRONG_PARTNER_USERNAME}")"
  if [[ "${wrong_status}" != "403" ]]; then
    echo "Expected wrong-owner project request to return 403, got ${wrong_status}" >&2
    cat "${tmp_dir}/wrong-owner.json" >&2
    exit 1
  fi

  if [[ "${RUN_PUBLISH}" == "true" ]]; then
    echo "Publishing ${PROJECT_ID}"
    publish_body="$(envelope "{\"publish\":{\"commitSha\":\"${commit_sha}\"}}")"
    api POST "/projects/${PROJECT_ID}/publish" "${publish_body}" "${tmp_dir}/publish.json"
    publish_operation="$(json_get "${tmp_dir}/publish.json" "workspaceOperation.operationId")"
    poll_operation "${publish_operation}" "${tmp_dir}/publish-operation.json"
  else
    echo "Skipping publish because RUN_PUBLISH=${RUN_PUBLISH}."
  fi

  echo "Managed repo: ${repository_url}"
  echo "Branch: ${branch}"
  echo "Commit: ${commit_sha}"
else
  echo "Skipping create/edit flow because RUN_CREATE_FLOW=${RUN_CREATE_FLOW}."
fi

if [[ "${RUN_PROJECT_CLEANUP}" == "true" ]]; then
  cleanup_project
else
  echo "Skipping project cleanup because RUN_PROJECT_CLEANUP=${RUN_PROJECT_CLEANUP}."
fi

echo "Workspace runner project/git E2E passed for ${PROJECT_ID}."
