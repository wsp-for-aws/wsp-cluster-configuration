How to install all in minikube
=

### Prerequisites
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [minikube](https://minikube.sigs.k8s.io/docs/start/)
- [argocd](https://argoproj.github.io/argo-cd/getting_started/)

### Steps

# Start minikube

```bash
minikube start
```

# Install ArgoCD
```bash
kubectl create namespace argocd
kubectl apply -n argocd --kustomize deploy/argocd
```

Port forward to argocd server
```bash
kubectl -n argocd port-forward deployments/argocd-server 8080:8080
```

Login via CLI argocd
```bash
argocd login localhost:8080 --username admin --password admin --insecure
```

Add minikube cluster to argocd with name `wsp-dev-cluster` by `cluster-admin` role
```bash
argocd cluster add minikube --name dev --insecure
```

Open ArgoCD UI in browser

http://localhost:8080
