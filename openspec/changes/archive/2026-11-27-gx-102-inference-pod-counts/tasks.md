## 1. Publish inference counts

- [x] 1.1 Add failing tests for the pod annotations and the layout config and metric entry. check: `helm unittest -f tests/inference_test.yaml src/groundx`
- [x] 1.2 Render the annotations, layout `threads` and `exactKeys`, mirror to `helm/`, and patch the snapshots whose config hash or annotations changed. check: `bash .build/bin/validate-helm.sh`
