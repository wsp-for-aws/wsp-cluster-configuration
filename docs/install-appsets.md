# How to deploy the ArgoCD application set to a ArgoCD server

```bash
# Set the current context to the ArgoCD namespace (CLI argocd don't support the --namespace flag)
kubectl config set-context --current --namespace=argocd

argocd appset create ./clusters/dev/application-set.yaml
argocd appset create ./clusters/.../application-set.yaml
```
