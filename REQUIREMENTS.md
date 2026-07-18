# Platform Requirements

The maintained requirements for the GitOps v2 platform. **Every accepted
requirement change lands here in the same PR that implements it.** Status:
✅ implemented · 🚧 partial · 📋 planned.

## R1 — Core principles

| # | Requirement | Status |
|---|---|---|
| R1.1 | **Easy to understand** — self-explanatory names, no underscores, folder names state what they hold (`charts`/`values`, `fleet`, `oneoffs`, `defaults`, `clusters`). | ✅ (addons; tenants/powergrader still use `_base`) |
| R1.2 | **DRY** — anything defined once: fleet-wide change = 1 edit, role/cloud-wide = 1 edit, chart version bump = 1 edit. | ✅ |
| R1.3 | **All Helm** — every WORKLOAD deploys as a Helm chart. No kustomize, no in-house renderer. (Hub appsets are deliberately NOT templated — see R4.3.) | ✅ |
| R1.4 | **Pure state repo** — `platform-config` holds desired state only; no CI writes generated files into it (unlike k8s-gitops `helm_values/`). | ✅ |
| R1.5 | **Grow by data, not appsets** — onboarding clusters/tenants/addons never adds an ApplicationSet; exactly one appset per plane, rendered per hub. | ✅ |

## R2 — Cluster identity & types

| # | Requirement | Status |
|---|---|---|
| R2.1 | Every cluster is declared once in the registry: `clusters/<region>/<cluster>/config.yaml`. | ✅ |
| R2.2 | Identity axes: **region** (path — decides the owning hub), **cloud** (`aws`/`azure`) and **role** (`primary`/`satellite`/`mgmt`) as content. | ✅ |
| R2.3 | **The law:** generators select by PATH, read CONTENT. Whatever decides *which* apps exist (ownership, placement) is a path segment; whatever describes *how* (cloud, role, pins) is file content. | ✅ (design rule) |
| R2.4 | A cluster exists in a hub iff BOTH its registry file and a cluster Secret (named = registry dir) exist in that hub. | ✅ (convention; CI check 📋) |

## R3 — Add-on plane

| # | Requirement | Status |
|---|---|---|
| R3.1 | Split by concern: `addons/charts/` = what runs & where; `addons/values/` = how it's tuned. | ✅ |
| R3.2 | Placement tiers by cluster TYPE: `fleet/` (all) < `roles/<role>/` < `clouds/<cloud>/`. | ✅ |
| R3.3 | **One-offs:** chart defined ONCE (`charts/oneoffs/<chart>/`), placed per cluster by a values-side placement file `values/oneoffs/<region>/<cluster>/<chart>/values.yaml`. Add a target = 1 file; version bump = 1 edit. | ✅ |
| R3.4 | Values ladder (last wins): `values/defaults/<addon>` → tier-level (mirror of the chart path) → `values/clusters/<cluster>/<addon>`. | ✅ |
| R3.5 | Per-cluster version pin (canary/hold-back): `addonOverrides.<addon>.chartVersion` in the cluster's registry file. | ✅ |

## R4 — Regional hubs (multi-ArgoCD)

| # | Requirement | Status |
|---|---|---|
| R4.1 | One ArgoCD per region (us/uk/eu + dev), each managing **its own cluster and its region's clusters** — no global hub. | ✅ (demo: dev hub on c1 → c2; prod hub on c3 → itself) |
| R4.2 | All hubs reconcile the ONE shared repo; each generates only its region's slice (registry glob `clusters/<region>/`). | ✅ |
| R4.3 | Hub appsets are PLAIN YAML per region (`hubs/<region>/appsets/` — readable exactly as ArgoCD runs them; no templating layer). Duplication is guarded by `bin/check-hub-drift.sh` (CI): regions must be identical modulo the region token. Bootstrapped by `hubs/<region>/root-app.yaml` (app-of-apps, self-managed). | ✅ |
| R4.4 | A hub holds credentials ONLY for its own region's clusters (blast radius / data sovereignty). | ✅ |
| R4.5 | Moving a cluster between regions = `git mv` the registry dir + move the Secret (+ oneoff placements). | ✅ (runbook in bootstrap/README) |

## R5 — Self-service (dev teams)

| # | Requirement | Status |
|---|---|---|
| R5.1 | Deploys happen via GitHub Actions calling DevOps-owned reusable workflows (`deploy`/`offboard`/`list-tenants`); engineers never write to this repo directly. | ✅ |
| R5.2 | Every change is an auditable commit authored by the triggering human (committer = bot, run link in trailers). | ✅ |
| R5.3 | Tenant/env is auto-located across clusters by the workflow (no cluster input). | ✅ |

## R6 — Operational requirements

| # | Requirement | Status |
|---|---|---|
| R6.1 | Migrations are zero-churn: generated app names stay stable across restructures, so cutover = in-place update / adoption, never redeploy. | ✅ (proven 5×) |
| R6.2 | Hub-to-hub handover without touching workloads: set `preserveResourcesOnDeletion` (or orphan-delete the appset) on the losing hub BEFORE re-scoping; the gaining hub adopts by matching app names/tracking-ids. **Stripping app finalizers is NOT safe — the appset controller re-adds them.** | 🚧 (incident 2026-07-18; runbook needed) |
| R6.3 | Structural appset changes are spike-verified first (no-sync copy on a branch) before cutover. | ✅ (working practice) |
| R6.4 | Git webhook → hubs (kill the cache-bust runbook; ×N hubs now). | 📋 |
| R6.5 | Per-plane AppProjects — tenants plane must not be able to target mgmt/other-region clusters. | 📋 |
| R6.6 | CI checks: hub-appset cross-region drift (✅ `check-hub-drift.yml`); registry file ⇄ hub Secret consistency (📋); `_`-free naming (📋). | 🚧 |

## R7 — Deferred / known debt

- Tenants & powergrader planes still use `_base/` naming and co-located values → migrate to the `charts/`+`values/` split (R1.1 completion).
- Cluster Secrets are created imperatively → External Secrets or sealed bootstrap (R2.4 hardening).
- Static GitHub dispatch forms (no live tenant/tag dropdowns) → portal (Backstage-class) later.
- Confluence design doc (2250047490) needs a full rewrite against v2 reality.

## Non-requirements (explicitly rejected)

- ❌ Post-selector filtering (`spec.selector`) — removed from ArgoCD 3.x CRD; all scoping must be path/glob based (see R2.3).
- ❌ Cluster-Secret labels as the source of identity — imperative, not reviewable in git.
- ❌ `managedBy:`/`region:` as file *content* — would state ownership twice (path already says it) and generators can't filter on content.
- ❌ Repo-per-region — kills DRY; only if compliance ever forces physical separation.
