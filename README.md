# platform-config

**Pure-state** config repo for the [GitOps Platform Design v2](https://apportoteam.atlassian.net/wiki/spaces/DevOps/pages/2250047490).
No templates, no rendering engine — just the desired state, in git. A **central
(hub) ArgoCD** on `gitops-c1` reconciles it onto the registered spoke clusters.

## Cluster types

Every cluster has two identity axes, declared once in the **cluster registry**:

| axis | values |
|---|---|
| `cloud` | `aws`, `azure` |
| `role` | `primary`, `satellite`, `mgmt` |

Demo fleet: `gitops-c2` = `{aws, satellite}` (dev/qa), `gitops-c3` = `{aws, primary}` (prod).

## Layout

```
applicationsets/
  tenants-appset.yaml            # tenant apps   (reads tenants/<cluster>/<tenant>/<app>)
  powergrader-appset.yaml        # powergrader   (reads powergrader/<cluster>/<env>/<app>)
  cluster-addons-appset.yaml     # add-ons, CLUSTER-TYPE aware (matrix: clusters/ x addons/)

clusters/                        # cluster registry — single source of cluster identity
  <cluster>/config.yaml          #   cloud + role (+ optional addonOverrides version pins)

addons/
  _base/<addon>/values.yaml            # fleet-wide addon values (define once)
  fleet/<addon>/config.yaml            # runs on EVERY cluster        (chart repo/version/ns)
  roles/<role>/<addon>/config.yaml     # runs on every <role> cluster (+ optional values.yaml)
  clouds/<cloud>/<addon>/config.yaml   # runs on every <cloud> cluster (+ optional values.yaml)
  oneoffs/<cluster>/<app>/config.yaml     # ONE-OFF: runs on that ONE named cluster (+ optional values.yaml)
  overrides/<cluster>/<addon>/values.yaml # per-cluster value escape hatch   [optional]

tenants/
  _base/values.yaml                    # global defaults (all clusters, all tenants)
  _base/<app>/values.yaml              # global per-app defaults
  <cluster>/_base/values.yaml          # per-cluster defaults (all tenants on it)   [optional]
  <cluster>/_base/<app>/values.yaml    # per-cluster per-app defaults               [optional]
  <cluster>/<tenant>/<app>/
    config.yaml                        # chart source ref (read by the generator)
    values.yaml                        # per-tenant override (image.tag lives here)

powergrader/
  <cluster>/<env>/<app>/{config.yaml,values.yaml}
```

- **Cluster is in the path.** The tenant/powergrader appsets take the target
  cluster from the `<cluster>` path segment; the addons appset takes it from the
  registry entry. Tenant dirs use the bare tenant id (e.g. `acme`); namespace is
  `tenant-<id>`.
- **Grow by data, not appsets.** Onboard a cluster = 1 registry file + 1 cluster
  `Secret` in the hub — all addons for its role/cloud follow automatically.
  Add a tenant = add a directory. Add an addon to every satellite = 1 file under
  `addons/roles/satellite/`. There is never a per-cluster appset.
- **Per-cluster version pin** (canary / hold-back): `addonOverrides.<addon>.chartVersion`
  in that cluster's registry file. It wins over the tier config's `chartVersion`.

## Values precedence (last wins)

Assembled by ArgoCD multi-source `valueFiles` (`ignoreMissingValueFiles: true`,
so optional tiers are skipped when absent).

Add-ons (`fleet` < `roles/<role>` < `clouds/<cloud>` < `oneoffs/<cluster>` — least → most specific placement):
```
chart defaults
→ addons/_base/<addon>/values.yaml               fleet-wide
→ addons/{fleet|roles/<role>|clouds/<cloud>|oneoffs/<cluster>}/<addon>/values.yaml   tier-level
→ addons/overrides/<cluster>/<addon>/values.yaml  per-cluster
```
A **one-off** platform component on a single cluster = one `addons/oneoffs/<cluster>/<app>/config.yaml`
(placement by cluster NAME). Do not use `roles/` for this — a second cluster of that
role would pick it up too.

Tenants:
```
chart defaults
→ tenants/_base/values.yaml                      global
→ tenants/_base/<app>/values.yaml                global per-app
→ tenants/<cluster>/_base/values.yaml            per-cluster (all tenants)
→ tenants/<cluster>/_base/<app>/values.yaml      per-cluster per-app
→ tenants/<cluster>/<tenant>/<app>/values.yaml   per-tenant
```

A fleet-wide change is **one edit** to `_base`; a role/cloud-wide change is one
edit to that tier — DRY without templating.

> `_base` directories contain **no `config.yaml`**, so the generators never turn
> them into Applications — they are pure value layers.

## Who writes here
Only the DevOps-owned reusable workflows (via a token), never engineers directly.
Every change is an auditable commit **authored by the human who triggered it**
(committer = the bot) and linked to its workflow run.
