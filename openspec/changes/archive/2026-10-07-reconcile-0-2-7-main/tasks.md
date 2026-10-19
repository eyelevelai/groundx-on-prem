## 1. Reconcile branches

- [x] 1.1 Merge main into the release branch and resolve workspace conflicts while preserving TLS, Secrets, Redis authentication, and ingress routing.
- [x] 1.2 Restore main's contributor guidance and check source regression coverage.

## 2. Refresh artifacts and validate

- [x] 2.1 Rebuild the main 0.2.7 archive and regenerate helm from its exact contents.
- [x] 2.2 Pass the full production Helm gate, both minikube renders, package parity, and strict OpenSpec validation.
- [x] 2.3 Close the exact local validation run root and retain a lifecycle receipt.

## 3. Promote

- [x] 3.1 Push the reconciled 0.2.7 branch and open the main promotion PR.
- [x] 3.2 Launch the main promotion PR integration jobs. Merge only after those jobs pass; registry publication and installation remain separate operator actions.
