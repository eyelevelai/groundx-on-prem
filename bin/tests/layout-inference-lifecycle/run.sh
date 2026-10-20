#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART="$(cd "${HERE}/../../../src/groundx" && pwd)"
NS="${NS:-gx115-lifecycle}"
IMAGE="${IMAGE:-layout-inference-stub:lifecycle}"
INIT_SLEEP="${INIT_SLEEP:-90}"
GRACE="${GRACE:-120}"
TASK_SECONDS="${TASK_SECONDS:-20}"
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
docker build -t "${IMAGE}" -f "${HERE}/Dockerfile.layout-inference-stub" "${HERE}"

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
VALUES=(
  --set "namespace=${NS}"
  --set "layout.inference.image=${IMAGE}"
  --set "layout.inference.imagePullPolicy=Never"
  --set "layout.inference.deviceType=cpu"
  --set "layout.inference.replicas.desired=1"
  --set "layout.inference.replicas.gracePeriod=${GRACE}"
  --set "cache.existing.addr=${REDIS_HOST}"
  --set "cache.existing.port=6379"
  --set "file.existing.url=http://${REDIS_HOST}:6379"
  --set "cluster.pvClass=standard"
)

render() {
  helm template groundx "${CHART}" "${VALUES[@]}" \
    -s templates/app/inference.yaml \
    -s templates/resources/layout-supervisord-conf.yaml \
    -s templates/resources/layout-config-py.yaml \
    -s templates/resources/config-models.yaml
}

apply_chart() {
  render | yq 'select(
      (.kind != "Deployment" and .kind != "PersistentVolumeClaim" and .kind != "PodDisruptionBudget")
      or .metadata.name == "layout-inference"
      or .metadata.name == "layout-model"
    )' \
    | k apply -f -
}

set_init_sleep() {
  k set env "deploy/${DEPLOY}" -c init-layout "INIT_LAYOUT_SLEEP=${INIT_SLEEP}"
}

enqueue() {
  k run "enqueue-$RANDOM" --rm -i --restart=Never --image="${IMAGE}" --image-pull-policy=Never \
    --env="BROKER_URL=redis://redis:6379/0" --env="RESULT_URL=redis://redis:6379/1" \
    --command -- python -c "
import os
from document.celery_process import work
for _ in range(${1}):
    work.delay(${TASK_SECONDS})
" >/dev/null
}

queue_depth() { redis_cli -n 0 llen layout_queue | tr -d '\r'; }
consumed_by() { redis_cli -n 1 llen "consumed:$1" | tr -d '\r'; }
completed_by() { redis_cli -n 1 llen "completed:$1" | tr -d '\r'; }

apply_chart
k scale "deploy/${DEPLOY}" --replicas=0
set_init_sleep
k scale "deploy/${DEPLOY}" --replicas=1

echo "== (a) pod deleted during init-layout"
enqueue 5
POD_A=""
until [[ -n "${POD_A}" ]]; do
  POD_A="$(k get pods -l "app=${DEPLOY}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  sleep 2
done
until [[ "$(k get pod "${POD_A}" -o jsonpath='{.status.initContainerStatuses[?(@.name=="init-layout")].state.running.startedAt}' 2>/dev/null)" != "" ]]; do
  sleep 2
done
DEPTH_BEFORE="$(queue_depth)"
k delete pod "${POD_A}" --wait=false
for _ in $(seq 1 "${GRACE}"); do
  k get pod "${POD_A}" >/dev/null 2>&1 || break
  enqueue 1
  sleep 1
done
CONSUMED_A="$(consumed_by "${POD_A}")"
echo "pod=${POD_A} queue_depth_before_delete=${DEPTH_BEFORE} consumed_by_pod=${CONSUMED_A}"
[[ "${CONSUMED_A}" == "0" ]] && check "(a) pod deleted during init consumed zero tasks" ok || check "(a) pod deleted during init consumed zero tasks" bad

echo "== (b) pod deleted after worker start"
k set env "deploy/${DEPLOY}" -c init-layout "INIT_LAYOUT_SLEEP=1"
k rollout status "deploy/${DEPLOY}" --timeout=300s || true
POD_B="$(k get pods -l "app=${DEPLOY}" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')"
until [[ "$(consumed_by "${POD_B}")" -ge 1 ]]; do
  enqueue 1
  sleep 2
done
INFLIGHT_BEFORE="$(completed_by "${POD_B}")"
k delete pod "${POD_B}" --wait=false
START="$(date +%s)"
until ! k get pod "${POD_B}" >/dev/null 2>&1; do sleep 1; done
ELAPSED=$(( $(date +%s) - START ))
CONSUMED_B="$(consumed_by "${POD_B}")"
COMPLETED_B="$(completed_by "${POD_B}")"
echo "pod=${POD_B} consumed=${CONSUMED_B} completed=${COMPLETED_B} completed_before_delete=${INFLIGHT_BEFORE} exit_seconds=${ELAPSED}"
[[ "${COMPLETED_B}" == "${CONSUMED_B}" ]] && check "(b) every consumed task completed before the pod exited" ok || check "(b) every consumed task completed before the pod exited" bad
[[ "${ELAPSED}" -le "${GRACE}" ]] && check "(b) pod exited within the grace period" ok || check "(b) pod exited within the grace period" bad

exit "${fail}"
