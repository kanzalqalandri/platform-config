# platform-config

**Pure-state** config repo for the [GitOps Platform Design v2](https://apportoteam.atlassian.net/wiki/spaces/DevOps/pages/2250047490).
No in-house rendering engine — just the desired state, in git. **Regional hub
ArgoCDs** (one per region, each managing its own region's clusters — including
itself) all reconcile from this ONE shared repo; each hub only generates the
slice scoped to its region.

See [REQUIREMENTS.md](REQUIREMENTS.md) for the maintained list of platform requirements.

## Cluster identity

Two axes as file **content**, one axis as the **path**:

| axis | where | values |
|---|---|---|
| `region` (which hub owns it) | **path**: `clusters/<region>/<cluster>/` | `us`, `uk`, `eu`, `dev` (demo: `dev`, `prod`) |
| `cloud` | file content | `aws`, `azure` |
| `role` | file content | `primary`, `satellite`, `mgmt` |

> **The law:** generators can **select by path** but only **read content**.
> Anything deciding *which* apps a hub generates (region/ownership, placement)
> must be a path segment; anything describing *how* (cloud, role, version pins)
> lives in file content.

Demo fleet: `clusters/dev/gitops-c2` = `{aws, satellite}` (managed by the dev hub on c1),
`clusters/prod/gitops-c3` = `{aws, primary}` (managed by the prod hub on c3 itself).

## Layout

```
hubs/
  <region>/appsets/*.yaml        # the 3 ApplicationSets, PLAIN YAML per region (no templating)
  <region>/root-app.yaml         # per-hub bootstrap Application (app-of-apps -> that dir)

clusters/                        # cluster registry — single source of cluster identity
  <region>/<cluster>/config.yaml #   region in the PATH; cloud + role (+ addonOverrides pins) in content

addons/                                # split by CONCERN — charts/ (what & where) vs values/ (how)
  charts/
    fleet/<addon>/config.yaml          # runs on EVERY cluster        (chart repo/version/ns)
    roles/<role>/<addon>/config.yaml   # runs on every <role> cluster
    clouds/<cloud>/<addon>/config.yaml # runs on every <cloud> cluster
    oneoffs/<chart>/config.yaml        # ONE-OFF chart, defined ONCE  (no cluster here)
  values/
    defaults/<addon>/values.yaml       # addon defaults (define once)
    <mirror of the chart's tier path>/values.yaml   # tier-level values (optional)
    oneoffs/<region>/<cluster>/<chart>/values.yaml  # PLACES a one-off chart on <cluster> (+ its values)
    clusters/<cluster>/<addon>/values.yaml  # per-cluster override of a tier addon  [optional]

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

Tier add-ons (`fleet` < `roles/<role>` < `clouds/<cloud>` — least → most specific, selected by cluster TYPE):
```
chart defaults
→ addons/values/defaults/<addon>/values.yaml                addon-wide
→ addons/values/{fleet|roles/<role>|clouds/<cloud>}/<addon>/values.yaml   tier-level
→ addons/values/clusters/<cluster>/<addon>/values.yaml      per-cluster
```
(The tier-level file is the chart's own path with `addons/charts/` swapped to `addons/values/`.)

**One-offs** are separate: the chart is defined once in `addons/charts/oneoffs/<chart>/config.yaml`,
and it deploys to **each cluster that has a placement file** `addons/values/oneoffs/<region>/<cluster>/<chart>/values.yaml`.
Add a target cluster = drop another placement file; bump the version = edit the one chart file.
For a *type* of cluster use `roles/`/`clouds/` instead — one-offs are for named, explicit placement.

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
