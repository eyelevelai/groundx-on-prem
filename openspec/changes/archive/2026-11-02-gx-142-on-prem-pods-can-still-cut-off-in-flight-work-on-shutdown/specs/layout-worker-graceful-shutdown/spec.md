## MODIFIED Requirements

### Requirement: Layout workers receive SIGTERM through exec supervisord
The chart SHALL render the container command of the five layout Celery workers (`layout-correct`, `layout-map`, `layout-ocr`, `layout-process`, `layout-save`) as `export PYTHONPATH=/app && exec supervisord -c /app/supervisord.conf`. The chart SHALL render `layout-inference` with a final init container named `init-layout` that runs `python /app/init-layout.py` from the `layout-inference` image, and SHALL render the `layout-inference` main container command as `/bin/sh -c "export PYTHONPATH=/app:$PYTHONPATH && exec supervisord -c /app/supervisord.conf"` with no init step in front of it, so `supervisord` is PID 1 from container start. The `init-layout` command SHALL be `/bin/sh -c "export PYTHONPATH=/app:$PYTHONPATH && exec python /app/init-layout.py"`. The chart SHALL NOT set an env `PYTHONPATH`, so an image-provided `PYTHONPATH` is preserved. The `init-layout` container SHALL carry the main container's `workingDir`, `resources` (including `nvidia.com/gpu`, or none in cpu mode), `envFrom` secrets, security context, CA environment and CA mount, and the `config-models`, `config-volume` and `model-volume` mounts. The layout worker and `layout-inference` commands, Supervisor stop wait and the `init-layout` init container SHALL be rendered through the shared Celery worker helper specified by the `worker-graceful-shutdown` capability, with a render byte-identical to the previous chart. Extract workers SHALL keep the command they render today. The startup commands of `ranker-inference`, `summary-inference` and the workspace workers are specified by the `worker-graceful-shutdown` capability.

#### Scenario: Layout Celery workers replace the shell (polarity: finalize success)
- **WHEN** the chart is rendered with default values
- **THEN** each of `layout-correct`, `layout-map`, `layout-ocr`, `layout-process` and `layout-save` has `exec supervisord` as the last command of its `command[2]` script

#### Scenario: layout-inference initializes in an init container and starts supervisord as PID 1 (polarity: finalize success)
- **WHEN** the chart is rendered with default values
- **THEN** `layout-inference` has an init container `init-layout`, listed after every other init container, running `exec python /app/init-layout.py` under `/bin/sh -c` with `PYTHONPATH=/app:$PYTHONPATH`
- **AND** the `layout-inference` main container command contains `exec supervisord -c /app/supervisord.conf`, contains no `init-layout.py`, and no container sets env `PYTHONPATH`

#### Scenario: layout-inference main container no longer runs init-layout (polarity: reject before state; catches)
- **WHEN** the chart is rendered with default values
- **THEN** no main-container command of `layout-inference` contains `init-layout.py`, so the shell-wait window in which a deletion signal was lost does not exist

#### Scenario: init-layout mirrors the main container's runtime context (polarity: finalize success)
- **WHEN** `layout-inference` is rendered with a file-access CA configured and a workload secret
- **THEN** the `init-layout` container has the same image, `workingDir`, `envFrom`, security context, CA env and CA mount as the main container, and mounts `config-models`, `config-volume` and `model-volume`

#### Scenario: init-layout requests the main container's resources (polarity: finalize success)
- **WHEN** `layout-inference` is rendered with default values (cuda)
- **THEN** `init-layout` has the same `nvidia.com/gpu` request and limit as the main container
- **AND** with `layout.inference.deviceType: cpu` neither container requests a GPU

#### Scenario: A failing init still stops the pod before Supervisor starts (polarity: finalize failure)
- **WHEN** `init-layout.py` exits non-zero
- **THEN** Kubernetes does not start the `layout-inference` main container, because the init container did not complete

#### Scenario: Extract workers keep their startup command (polarity: skip unrelated repair path; must not block)
- **WHEN** the chart is rendered with `extract.enabled=true`
- **THEN** the extract workers render the same `exec supervisord` command as the previous chart

#### Scenario: Ranker and summary inference gain no init container (polarity: skip unrelated repair path; must not block)
- **WHEN** the chart is rendered with default values
- **THEN** `ranker-inference` and `summary-inference` have no `init-layout` init container

#### Scenario: Pod deleted during init never starts Celery (polarity: reject before state; verified by the recorded GX-115 lifecycle runs on minikube and EKS)
- **WHEN** a `layout-inference` pod from the chart's rendered output is deleted while `init-layout` is still running
- **THEN** the main container never starts, so no Celery worker starts and zero tasks are consumed, measured from the broker/result side while tasks keep being enqueued
- **AND** the minikube lifecycle run used real supervisord and real Celery against the chart's unedited `supervisord.conf`, with only `init-layout.py` and a minimal Celery app as stand-ins
- **AND** the same run failed against the previous chart, where Celery starts after init and consumes tasks

#### Scenario: Pod deleted after start shuts down warm (polarity: finalize success; verified by the recorded GX-115 lifecycle runs on minikube and EKS)
- **WHEN** a `layout-inference` pod from the chart's rendered output is deleted after `supervisord` has started
- **THEN** `supervisord` receives SIGTERM as PID 1 and the real Celery worker stops through warm shutdown within the rendered grace period

#### Scenario: Layout renders are unchanged by the shared helper (polarity: finalize success; must not block)
- **WHEN** the chart is rendered with default values, `imageType: chainguard`, and two workers per layout family
- **THEN** each layout worker Deployment and `layout-inference`, including its `init-layout` init container, and each layout Supervisor config is byte-identical to the previous chart
- **AND** the existing `inference_test.yaml` cases pass unchanged

### Requirement: Layout worker pods default to a 900-second grace period
The chart SHALL render `terminationGracePeriodSeconds: 900` on the five layout Celery worker Deployments and on `layout-inference` when no grace period is set, and SHALL render the value of `layout.<service>.replicas.gracePeriod` on the Deployment of that service when it is set. The 900-second default SHALL be defined once in the shared Celery worker helper, not per workload template. The grace period of `ranker-inference`, `summary-inference` and the workspace workers is specified by the `worker-graceful-shutdown` capability.

#### Scenario: Default grace period (polarity: finalize success)
- **WHEN** the chart is rendered with default values
- **THEN** each of the six layout workloads has `terminationGracePeriodSeconds: 900`

#### Scenario: Override applies to one service only (polarity: finalize success)
- **WHEN** `layout.map.replicas.gracePeriod` is set to 120 and no other grace period is set
- **THEN** `layout-map` renders `terminationGracePeriodSeconds: 120`
- **AND** `layout-correct` still renders 900

#### Scenario: layout-inference accepts its own override (polarity: finalize success)
- **WHEN** `layout.inference.replicas.gracePeriod` is set to 120
- **THEN** `layout-inference` renders `terminationGracePeriodSeconds: 120`

#### Scenario: A layout override does not reach other inference services (polarity: skip unrelated repair path; must not block)
- **WHEN** `layout.inference.replicas.gracePeriod` is set to 120 and no ranker or summary grace period is set
- **THEN** `layout-inference` renders 120
- **AND** `ranker-inference` and `summary-inference` still render 900
