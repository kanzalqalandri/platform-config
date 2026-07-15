# bootstrap

Apply the dev ApplicationSet to your cluster once ArgoCD is installed:

```bash
kubectl apply -n argocd -f ../applicationsets/dev-appset.yaml
```

ArgoCD then discovers every `envs/dev/<tenant>/<app>/config.yaml` and creates an
Application per tenant/app automatically. Adding a tenant = add a directory;
removing one = delete the directory (see the offboard workflow).
