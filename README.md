# platform-config

**Pure-state** config repo for the [GitOps Platform Design v2](https://apportoteam.atlassian.net/wiki/spaces/DevOps/pages/2250047490).
No templates, no rendering engine — just the desired state, in git. A **central
(hub) ArgoCD** on `gitops-c1` reconciles it onto the registered spoke clusters.

## Layout

```
applicationsets/
  tenants-appset.yaml            # tenant apps  (reads tenants/<cluster>/<tenant>/<app>)
  cluster-addons-appset.yaml     # cluster add-ons (reads addons/<cluster>/<addon>)

tenants/
  _base/values.yaml                    # global defaults (all clusters, all tenants)
  _base/<app>/values.yaml              # global per-app defaults
  <cluster>/_base/values.yaml          # per-cluster defaults (all tenants on it)   [optional]
  <cluster>/_base/<app>/values.yaml    # per-cluster per-app defaults               [optional]
  <cluster>/<tenant>/<app>/
    config.yaml                        # chart source ref (read by the generator)
    values.yaml                        # per-tenant override (image.tag lives here)

addons/
  <cluster>/<addon>/
    config.yaml                        # upstream chart repo/chart/version + namespace + syncWave
    values.yaml                        # helm values for the add-on
```

- **Cluster is in the path.** Both appsets take the target cluster from the
  `<cluster>` path segment (`destination.name`) and deploy there via the hub.
  The tenant directory is the bare tenant id (e.g. `acme`); its namespace is
  `tenant-<id>`.
- **Grow by data, not appsets.** Add a cluster = register a cluster `Secret` in
  the hub. Add a tenant/add-on = add a directory. Move a tenant to another
  cluster = move its directory. There is never a per-cluster appset.

## Values precedence (last wins)

Assembled by ArgoCD multi-source `valueFiles` (`ignoreMissingValueFiles: true`,
so the optional `_base` tiers are skipped when absent):

```
chart defaults
→ tenants/_base/values.yaml                      global
→ tenants/_base/<app>/values.yaml                global per-app
→ tenants/<cluster>/_base/values.yaml            per-cluster (all tenants)
→ tenants/<cluster>/_base/<app>/values.yaml      per-cluster per-app
→ tenants/<cluster>/<tenant>/<app>/values.yaml   per-tenant
```

A fleet-wide change is **one edit** to `tenants/_base`; a cluster-wide change is
one edit to `tenants/<cluster>/_base` — DRY without templating.

> `_base` directories contain **no `config.yaml`**, so the generators
> (`tenants/*/*/*/config.yaml`, `addons/*/*/config.yaml`) never turn them into
> Applications — they are pure value layers.

## Who writes here
Only the DevOps-owned reusable workflows (via a token), never engineers directly.
Every change is an auditable commit **authored by the human who triggered it**
(committer = the bot) and linked to its workflow run.
