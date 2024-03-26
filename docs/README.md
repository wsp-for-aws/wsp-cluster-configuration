Documentation
=

- [Install ArgoCD](../deploy/install-argocd.md)


### How to deploy the ArgoCD application to the WSP ArgoCD server

```bash
kubectl config set-context --current --namespace=argocd

argocd app create -f ./application.yaml
# OR
argocd appset create -f ./argocd/application-set.yaml
# OR
argocd appset create -f ./clusters/dev/application-set.yaml
argocd appset create -f ./clusters/.../application-set.yaml
```