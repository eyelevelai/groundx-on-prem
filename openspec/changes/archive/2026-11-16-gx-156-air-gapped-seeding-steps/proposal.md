## Why

`docs/upgrades.md` § "Inference model downloads" fails an air-gapped cluster on two paths. The recovery for a false `complete.<model>` marker left by an older chart ends with "The next pod downloads the model again", which an air-gapped pod cannot do. Older charts wrote that false marker on every air-gapped first start, so these clusters are the most likely to need the recovery. The air-gapped paragraph ("Copy the model files and the `complete.<model>` file into the model volume before scaling up") does not say where the files come from, where the copy runs, that the parts must be extracted, or that the marker must be written last.

## What Changes

- The false-marker recovery tells an air-gapped cluster to re-seed the volume (all four steps, starting with the download on a connected machine) instead of waiting for a download.
- The air-gapped paragraph becomes a numbered procedure: download the parts on a connected machine, scale the service to 0 and wait, seed from a short-lived pod that mounts the claim and runs as user 1001 (extract each part in order into the volume root, delete the parts, create `complete.<model>` last), scale back up. One example command block.
- It covers all three services: ranker and summary download archive parts in `download-model`, and layout downloads four `.pth`/`.yaml` files in its `init-layout` init container (ai-server `document/model.py` and `models/layout.py`), skipping files already present; layout's `download-model` has no parts and fetches nothing. The steps seed the layout files under their URL names. An upgrade that changes a model needs the new model seeded first.
- Docs only: no template, value, image or snapshot change.

## Capabilities

### Modified Capabilities
- `inference-model-download-lock`: the upgrade-guide requirement covers the air-gapped seeding procedure and the air-gapped false-marker recovery.

## Impact

- **Blast radius:** `docs/upgrades.md` only.
- **Verified:** the seeding commands (`tar -xzf` each part, `rm`, `touch` the marker) were run in the chart busybox image as user 1001; the files are owned by 1001. The `kubectl run --overrides` JSON parses. The full `kubectl` sequence was not run against a cluster.
