# Configure Workspace Ownership Checks Tasks

## 1. Contract And Tests

- [ ] Add default and explicit-false Helm unit tests.
- [ ] Add strict schema coverage for the boolean value.
- [ ] Confirm the tests fail before implementation.

## 2. Source Chart

- [ ] Add the default-on value to `src/groundx/values.yaml`.
- [ ] Add the strict boolean schema field.
- [ ] Add the default-on helper.
- [ ] Render the Python setting in workspace `config.py`.
- [ ] Document the value and rollout order.

## 3. Published Mirror

- [ ] Mirror every changed chart file under `helm/`.
- [ ] Confirm the changed source and mirror files match.

## 4. Verification

- [ ] Regenerate snapshots with `helm unittest -u src/groundx`.
- [ ] Run `helm lint src/groundx`.
- [ ] Run the minikube render check.
- [ ] Run `helm unittest src/groundx`.
- [ ] Run strict OpenSpec validation.
- [ ] Run `git diff --check`.

## 5. Rollout

- [ ] Deploy the compatible runner image before this chart.
- [ ] Verify default-on startup before setting the internal environment to false.
- [ ] Prove rollback to true before production completion.
