Install ArgoCD in minikube
=

```bash
minikube start
```

```bash
minikube addons enable ingress
```

Install ArgoCD
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/install.yaml
```

Setup admin password to 'admin'
```bash
kubectl -n argocd patch secret argocd-secret   -p '{"stringData": {
    "admin.password": "$2a$10$48U85bahwi7Vb4TQeFnvuOBLqhuDuHGvX22IRQYBwOZeCBoUhLV2K",
    "admin.passwordMtime": "'$(date +%FT%T%Z)'"
  }}'
```

Port forward to argocd server
```bash
kubectl -n argocd port-forward deployments/argocd-server 8080:8080
```

Login via CLI argocd
```
argocd login localhost:8080 --username admin --password admin --insecure
```

Open ArgoCD UI http://localhost:8080
