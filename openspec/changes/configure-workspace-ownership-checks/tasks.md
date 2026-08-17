# Configure Workspace Ownership Checks Tasks

## 1. Contract And Tests

- [x] Add default and explicit-false Helm unit tests.
- [x] Add strict schema coverage for the boolean value.
- [x] Confirm the tests fail before implementation.

## 2. Source Chart

- [x] Add the default-on value to `src/groundx/values.yaml`.
- [x] Add the strict boolean schema field.
- [x] Add the default-on helper.
- [x] Render the Python setting in workspace `config.py`.
- [x] Document the value and rollout order.

## 3. Published Mirror

- [x] Mirror every changed chart file under `helm/`.
- [x] Confirm the changed source and mirror files match.

## 4. Verification

- [x] Regenerate snapshots with `helm unittest -u src/groundx`.
- [x] Run `helm lint src/groundx`.
- [x] Run the minikube render check.
- [x] Run `helm unittest src/groundx`.
- [x] Run strict OpenSpec validation.
- [x] Run `git diff --check`.

## 5. Rollout

- [ ] Deploy the compatible runner image before this chart.
- [ ] Verify default-on startup before setting the internal environment to false.
- [ ] Prove rollback to true before production completion.
