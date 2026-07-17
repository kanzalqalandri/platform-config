# bootstrap

Central **hub** ArgoCD runs on `gitops-c1`; other clusters are **spokes**
registered into it. Once ArgoCD is installed on the hub, apply the appsets:

```bash
kubectl apply -n argocd -f ../applicationsets/tenants-appset.yaml
kubectl apply -n argocd -f ../applicationsets/powergrader-appset.yaml
kubectl apply -n argocd -f ../applicationsets/cluster-addons-appset.yaml
```

## Onboarding a cluster — TWO things must exist

1. A **registry file** `clusters/<cluster>/config.yaml` declaring `cloud` + `role`
   (this is what decides which add-ons it runs).
2. A **cluster Secret** in the hub's `argocd` namespace, named exactly like the
   registry dir (label `argocd.argoproj.io/secret-type: cluster`) — see the
   `argocd-manager` ServiceAccount pattern used for c2/c3.

If the registry file exists without the Secret, its generated Applications stick
on "cluster not found". If the Secret exists without the registry file, the
cluster gets no add-ons (tenants/powergrader still work — they route by path).

The generators then auto-discover work:
- `clusters/<cluster>/config.yaml` × `addons/{all,roles/<role>,clouds/<cloud>}/<addon>/config.yaml`
  → one Application per (cluster, applicable addon).
- `tenants/<cluster>/<tenant>/<app>/config.yaml` → one Application per tenant/app.
- `powergrader/<cluster>/<env>/<app>/config.yaml` → one Application per env/app.

Adding a tenant/add-on = add a file; removing one = delete it (the offboard
workflow does this, and ArgoCD cascades the cleanup).
