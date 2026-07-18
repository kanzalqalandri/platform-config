# hubs-kustomize — comparison artifact (NOT live)

The same 3 hub ApplicationSets as `hubs/chart`, expressed with **kustomize**
(base + per-region overlay) instead of Helm. Built to compare which variant is
easier to follow. **The live hubs run `hubs/chart`** — nothing here is applied.

Verified: for both regions, `kubectl kustomize hubs-kustomize/overlays/<region>`
renders ApplicationSet specs **byte-identical** to
`helm template hub hubs/chart --set region=<region>`.

```
base/                        # the 3 appsets, plain YAML, region = "REGION" sentinel
overlays/dev/                # kustomization.yaml patching the 4 region-bearing globs
overlays/prod/
root-app.dev.example.yaml    # what a hub bootstrap would look like (example only)
```

Render to read: `kubectl kustomize overlays/dev`

## The three variants, honestly compared

| | Helm chart (`hubs/chart`) — LIVE | plain YAML/region (in history, `0b44be7`) | kustomize (this dir) |
|---|---|---|---|
| The appset you read is what runs | ❌ mentally strip `{{ `…` }}` escaping | ✅ exactly | ⚠ base is *almost* it — region is a sentinel; you must mentally apply the overlay patch |
| Region defined | 1 value in root-app | in-file, ×N regions | 4 JSON6902 ops per overlay |
| Single source of truth | ✅ one template | ❌ N copies (CI-guarded) | ✅ one base + thin overlays |
| Add a region | 1 root-app (4 lines) | copy dir, change string | 1 overlay (~30 lines of patches) |
| Failure mode when editing | Helm render error (loud, at sync) | drift (caught by CI check) | **index-based patch paths**: reorder/insert a generator in base and `/spec/generators/1/...` silently patches the WRONG element |
| Comments survive to the cluster | ✅ (helm passes them through) | ✅ | ❌ `kustomize build` strips comments |
| Extra toolchain in an all-Helm shop | none (Helm already the renderer) | none | kustomize (breaks R1.3's "no kustomize") |
| Read the final form | `helm template hub hubs/chart --set region=dev` | `cat` | `kubectl kustomize overlays/dev` |

**The kustomize-specific risk in one sentence:** the overlays address patch
targets *by list index* (`/spec/generators/0/matrix/generators/0/git/files/0/path`);
nothing ties those numbers to *meaning*, so a reordering edit in base can
mispatch silently — the class of error the other two variants surface loudly.

## Decision

Record the outcome in REQUIREMENTS.md (R4.3) and delete the losing variant(s);
plain-YAML-per-region remains available in git history at merge `0b44be7`.
