#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART="$(cd "${HERE}/../../../src/groundx" && pwd)"
NS="${NS:-gx115-lifecycle}"
IMAGE_REPO="${IMAGE_REPO:-layout-inference-stub}"
IMAGE_SLOW="${IMAGE_REPO}:init-slow"
IMAGE_FAST="${IMAGE_REPO}:init-fast"
IMAGE_FAIL="${IMAGE_REPO}:init-fail"
INIT_SLEEP="${INIT_SLEEP:-90}"
GRACE="${GRACE:-120}"
TASK_SECONDS="${TASK_SECONDS:-20}"
POD_WAIT="${POD_WAIT:-300}"
OBSERVE_SECONDS="${OBSERVE_SECONDS:-30}"
DEPLOY=layout-inference

for tool in minikube kubectl helm yq docker; do
  command -v "${tool}" >/dev/null || { echo "missing required tool: ${tool}" >&2; exit 1; }
done

fail=0
check() {
  if [[ "$2" == "ok" ]]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi
}

k() { kubectl -n "${NS}" "$@"; }
redis_cli() { k exec deploy/redis -- redis-cli "$@"; }

eval "$(minikube docker-env)"
docker build -t "${IMAGE_SLOW}" --build-arg "INIT_LAYOUT_SLEEP=${INIT_SLEEP}" -f "${HERE}/Dockerfile.layout-inference-stub" "${HERE}"
docker build -t "${IMAGE_FAST}" --build-arg "INIT_LAYOUT_SLEEP=1" -f "${HERE}/Dockerfile.layout-inference-stub" "${HERE}"
docker build -t "${IMAGE_FAIL}" --build-arg "INIT_LAYOUT_SLEEP=1" --build-arg "INIT_LAYOUT_EXIT=1" -f "${HERE}/Dockerfile.layout-inference-stub" "${HERE}"

kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -

cat <<MANIFEST | k apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
spec:
  replicas: 1
  selector:
    matchLabels: {app: redis}
  template:
    metadata:
      labels: {app: redis}
    spec:
      containers:
        - name: redis
          image: redis:7
          ports: [{containerPort: 6379}]
---
apiVersion: v1
kind: Service
metadata:
  name: redis
spec:
  selector: {app: redis}
  ports: [{port: 6379, targetPort: 6379}]
MANIFEST
k rollout status deploy/redis --timeout=120s

REDIS_HOST="redis.${NS}.svc.cluster.local"

render() {
  helm template groundx "${CHART}" \
    --set "namespace=${NS}" \
    --set "layout.inference.image=$1" \
    --set "layout.inference.imagePullPolicy=Never" \
    --set "layout.inference.deviceType=cpu" \
    --set "layout.inference.node=" \
    --set "layout.inference.replicas.desired=$2" \
    --set "layout.inference.replicas.gracePeriod=${GRACE}" \
    --set "cache.existing.addr=${REDIS_HOST}" \
    --set "cache.existing.port=6379" \
    --set "file.existing.url=http://${REDIS_HOST}:6379" \
    --set "cluster.type=minikube" \
    --set "cluster.pvClass=standard" \
    -s templates/app/inference.yaml \
    -s templates/resources/layout-supervisord-conf.yaml \
    -s templates/resources/layout-config-py.yaml \
    -s templates/resources/config-models.yaml
}

apply_chart() {
  render "$1" "$2" | yq 'select(
      (.kind != "Deployment" and .kind != "PersistentVolumeClaim" and .kind != "PodDisruptionBudget")
      or .metadata.name == "layout-inference"
      or .metadata.name == "layout-model"
    )' \
    | k apply -f -
}

wait_until() {
  local desc="$1" timeout="$2"
  shift 2
  local end=$(( SECONDS + timeout ))
  until "$@"; do
    if (( SECONDS >= end )); then
      echo "FAIL: timed out after ${timeout}s waiting for ${desc}"
      k get pods -o wide || true
      k describe "deploy/${DEPLOY}" | tail -30 || true
      exit 1
    fi
    sleep 2
  done
}

POD=""
have_pod() {
  POD="$(k get pods -l "app=${DEPLOY}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  [[ -n "${POD}" ]]
}
pod_scheduled() {
  [[ "$(k get pod "${POD}" -o jsonpath='{.status.conditions[?(@.type=="PodScheduled")].status}' 2>/dev/null)" == "True" ]]
}
init_started() { [[ "$(init_started_count "${POD}")" -ge 1 ]]; }
pod_running() { [[ "$(k get pod "${POD}" -o jsonpath='{.status.phase}' 2>/dev/null)" == "Running" ]]; }
no_pods() { [[ -z "$(k get pods -l "app=${DEPLOY}" -o name 2>/dev/null)" ]]; }
pod_gone() { ! k get pod "$1" >/dev/null 2>&1; }

queue_depth() { redis_cli -n 0 llen layout_queue | tr -d '\r'; }
consumed_by() { redis_cli -n 1 llen "consumed:$1" | tr -d '\r'; }
completed_by() { redis_cli -n 1 llen "completed:$1" | tr -d '\r'; }
init_started_count() { redis_cli -n 1 llen "init-started:$1" | tr -d '\r'; }

enqueue() {
  k run "enqueue-$RANDOM" --rm -i --restart=Never --image="${IMAGE_FAST}" --image-pull-policy=Never \
    --env="BROKER_URL=redis://redis:6379/0" --env="RESULT_URL=redis://redis:6379/1" \
    --command -- python -c "
from document.celery_process import work
for _ in range(${1}):
    work.delay(${TASK_SECONDS})
" >/dev/null
}

reset_deployment() {
  k scale "deploy/${DEPLOY}" --replicas=0 >/dev/null 2>&1 || true
  wait_until "layout-inference pods to terminate" $(( GRACE + 60 )) no_pods
  redis_cli flushall >/dev/null
}

start_with_queued_tasks() {
  reset_deployment
  apply_chart "$1" 0
  enqueue "$2"
  k scale "deploy/${DEPLOY}" --replicas=1
  wait_until "layout-inference pod to appear" "${POD_WAIT}" have_pod
  wait_until "pod ${POD} to be scheduled" "${POD_WAIT}" pod_scheduled
  wait_until "init-layout.py to start in pod ${POD}" "${POD_WAIT}" init_started
}

echo "== (a) pod deleted during init-layout"
start_with_queued_tasks "${IMAGE_SLOW}" 5
POD_A="${POD}"
DEPTH_BEFORE="$(queue_depth)"
k delete pod "${POD_A}" --wait=false
end=$(( SECONDS + GRACE + 60 ))
until pod_gone "${POD_A}"; do
  if (( SECONDS >= end )); then
    echo "FAIL: pod ${POD_A} still present after $(( GRACE + 60 ))s"
    exit 1
  fi
  enqueue 1
  sleep 1
done
CONSUMED_A="$(consumed_by "${POD_A}")"
echo "pod=${POD_A} queue_depth_before_delete=${DEPTH_BEFORE} consumed_by_pod=${CONSUMED_A}"
[[ "${CONSUMED_A}" == "0" ]] && check "(a) pod deleted during init consumed zero tasks" ok || check "(a) pod deleted during init consumed zero tasks" bad

echo "== (b) pod deleted after worker start"
reset_deployment
apply_chart "${IMAGE_FAST}" 1
wait_until "layout-inference pod to appear" "${POD_WAIT}" have_pod
wait_until "pod ${POD} to be scheduled" "${POD_WAIT}" pod_scheduled
wait_until "init-layout.py to start in pod ${POD}" "${POD_WAIT}" init_started
wait_until "pod ${POD} to be Running" "${POD_WAIT}" pod_running
POD_B="${POD}"
end=$(( SECONDS + POD_WAIT ))
until [[ "$(consumed_by "${POD_B}")" -ge 1 ]]; do
  if (( SECONDS >= end )); then
    echo "FAIL: pod ${POD_B} consumed no task within ${POD_WAIT}s"
    k logs "${POD_B}" --all-containers --tail=40 || true
    exit 1
  fi
  enqueue 1
  sleep 2
done
INFLIGHT_BEFORE="$(completed_by "${POD_B}")"
k delete pod "${POD_B}" --wait=false
START="$(date +%s)"
wait_until "pod ${POD_B} to exit" $(( GRACE + 60 )) pod_gone "${POD_B}"
ELAPSED=$(( $(date +%s) - START ))
CONSUMED_B="$(consumed_by "${POD_B}")"
COMPLETED_B="$(completed_by "${POD_B}")"
echo "pod=${POD_B} consumed=${CONSUMED_B} completed=${COMPLETED_B} completed_before_delete=${INFLIGHT_BEFORE} exit_seconds=${ELAPSED}"
[[ "${COMPLETED_B}" == "${CONSUMED_B}" ]] && check "(b) every consumed task completed before the pod exited" ok || check "(b) every consumed task completed before the pod exited" bad
[[ "${ELAPSED}" -le "${GRACE}" ]] && check "(b) pod exited within the grace period" ok || check "(b) pod exited within the grace period" bad

echo "== (c) init-layout exits non-zero"
start_with_queued_tasks "${IMAGE_FAIL}" 5
POD_C="${POD}"
DEPTH_C_BEFORE="$(queue_depth)"
sleep "${OBSERVE_SECONDS}"
CONSUMED_C="$(consumed_by "${POD_C}")"
DEPTH_C_AFTER="$(queue_depth)"
HAS_INIT_CONTAINER="$(k get pod "${POD_C}" -o jsonpath='{.spec.initContainers[?(@.name=="init-layout")].name}')"
MAIN_STARTED="$(k get pod "${POD_C}" -o jsonpath='{.status.containerStatuses[0].started}{.status.containerStatuses[0].state.running.startedAt}{.status.containerStatuses[0].lastState.terminated.startedAt}')"
echo "pod=${POD_C} queue_depth_before=${DEPTH_C_BEFORE} queue_depth_after=${DEPTH_C_AFTER} consumed_by_pod=${CONSUMED_C} init_container_present=${HAS_INIT_CONTAINER:-no} main_container_start_evidence=${MAIN_STARTED:-none}"
[[ "${CONSUMED_C}" == "0" && "${DEPTH_C_AFTER}" == "${DEPTH_C_BEFORE}" ]] && check "(c) failed init consumed zero tasks and left the queue undrained" ok || check "(c) failed init consumed zero tasks and left the queue undrained" bad
if [[ -n "${HAS_INIT_CONTAINER}" ]]; then
  [[ -z "${MAIN_STARTED//false/}" ]] && check "(c) main container never started after init failure" ok || check "(c) main container never started after init failure" bad
else
  echo "NOTE: (c) chart has no init-layout init container; init-layout.py runs inside the main container, so main-container start is not separately assertable (zero consumption above is the signal)"
fi

reset_deployment
exit "${fail}"
