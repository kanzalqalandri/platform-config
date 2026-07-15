# bootstrap

Central **hub** ArgoCD runs on `gitops-c1`; other clusters are **spokes**
registered into it. Once ArgoCD is installed on the hub, apply the appsets:

```bash
kubectl apply -n argocd -f ../applicationsets/tenants-appset.yaml
kubectl apply -n argocd -f ../applicationsets/cluster-addons-appset.yaml
```

To add a spoke cluster, register it in the hub (a cluster `Secret` labelled
`argocd.argoproj.io/secret-type: cluster`, named e.g. `gitops-c2`) — see the
`argocd-manager` ServiceAccount pattern used for c2/c3.

The generators then auto-discover work:
- `tenants/<cluster>/<tenant>/<app>/config.yaml` → one Application per tenant/app,
  deployed to the cluster named in the path.
- `addons/<cluster>/<addon>/config.yaml` → one Application per add-on.

Adding a tenant/add-on = add a directory; removing one = delete the directory
(the offboard workflow does this, and ArgoCD cascades the cleanup).
