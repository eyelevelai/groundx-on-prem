## MODIFIED Requirements

### Requirement: Layout workers receive SIGTERM through exec supervisord
The chart SHALL render the container command of the five layout Celery workers (`layout-correct`, `layout-map`, `layout-ocr`, `layout-process`, `layout-save`) as `export PYTHONPATH=/app && exec supervisord -c /app/supervisord.conf`. The chart SHALL render `layout-inference` with a final init container named `init-layout` that runs `python /app/init-layout.py` from the `layout-inference` image, and SHALL render the `layout-inference` main container command as `/bin/sh -c "export PYTHONPATH=/app:$PYTHONPATH && exec supervisord -c /app/supervisord.conf"` with no init step in front of it, so `supervisord` is PID 1 from container start. The `init-layout` command SHALL be `/bin/sh -c "export PYTHONPATH=/app:$PYTHONPATH && exec python /app/init-layout.py"`. The chart SHALL NOT set an env `PYTHONPATH`, so an image-provided `PYTHONPATH` is preserved. The `init-layout` container SHALL carry the main container's `workingDir`, `resources` (including `nvidia.com/gpu`, or none in cpu mode), `envFrom` secrets, security context, CA environment and CA mount, and the `config-models`, `config-volume` and `model-volume` mounts. Workspace workers, extract workers, `ranker-inference` and `summary-inference` SHALL keep the commands they render today.

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

#### Scenario: Other workloads keep their startup command (polarity: skip unrelated repair path; must not block)
- **WHEN** the chart is rendered with `workspace.enabled=true`
- **THEN** `workspace-workspace` keeps `export PYTHONPATH=/app && supervisord -c /app/supervisord.conf` with no `exec`
- **AND** `ranker-inference` and `summary-inference` keep their current command with no `exec`, and gain no `init-layout` init container

#### Scenario: Pod deleted during init never starts Celery (polarity: reject before state; hand-run lifecycle test)
- **WHEN** a `layout-inference` pod from the chart's rendered output is deleted while `init-layout` is still running
- **THEN** the main container never starts, so no Celery worker starts and zero tasks are consumed, measured from the broker/result side while tasks keep being enqueued
- **AND** the test runs real supervisord and real Celery against the chart's unedited `supervisord.conf`, with only `init-layout.py` and a minimal Celery app as stand-ins
- **AND** the same test fails against the previous chart, where Celery starts after init and consumes tasks

#### Scenario: Pod deleted after start shuts down warm (polarity: finalize success; hand-run lifecycle test)
- **WHEN** a `layout-inference` pod from the chart's rendered output is deleted after `supervisord` has started
- **THEN** `supervisord` receives SIGTERM as PID 1 and the real Celery worker stops through warm shutdown within the rendered grace period

### Requirement: Existing values files keep validating and rendering
Values files that do not set `gracePeriod` SHALL keep validating. The only rendered differences from the previous chart for such files SHALL be the layout workloads' pod grace period, `exec` command, Supervisor `stopwaitsecs`, the `[group:celery_workers]` Supervisor section and the resulting `supervisord-hash` annotation, and the `layout-inference` `init-layout` init container with its direct `supervisord` main command.

#### Scenario: Backward compatibility with values that omit gracePeriod (polarity: finalize success)
- **WHEN** a values file written for the previous chart, with no `gracePeriod` under `layout`, is rendered
- **THEN** it validates and renders
- **AND** the rendered `ranker-inference`, `summary-inference`, workspace and extract workloads are byte-identical to the previous chart

#### Scenario: Helm mirror stays identical (polarity: finalize success)
- **WHEN** the changed templates under `src/groundx/templates` are compared with `helm/templates`
- **THEN** they are byte-identical
