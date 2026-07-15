# platform-config

**Pure-state** config repo for the [GitOps Platform Design v2](https://apportoteam.atlassian.net/wiki/spaces/DevOps/pages/2250047490).
No templates, no rendering engine — just the desired state, in git.

## Layout

```
applicationsets/dev-appset.yaml          # one ApplicationSet per env (multi-source)
envs/dev/
  _base/values.yaml                      # env-wide defaults (all apps)
  _base/gitops-demo-app/values.yaml      # app-wide defaults (all tenants)
  <tenant>/gitops-demo-app/
    config.yaml                          # chart source ref (read by the generator)
    values.yaml                          # thin tenant override (image.tag lives here)
```

Values precedence (last wins), assembled by ArgoCD multi-source `valueFiles`:
`chart defaults` → `_base/values.yaml` → `_base/<app>/values.yaml` → `<tenant>/<app>/values.yaml`.

A fleet-wide change is **one edit** to a `_base` file — DRY without templating.

## Who writes here
Only the DevOps-owned reusable workflows (via a token), never engineers directly.
Every change is an auditable commit tied to a workflow run.
