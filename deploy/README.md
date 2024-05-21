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
# OR with OIDC enabled
minikube start \
    --extra-config=apiserver.oidc-issuer-url=https://idp.k8s-staging.plesk.tech \
    --extra-config=apiserver.oidc-client-id=kubelogin \
    --extra-config=apiserver.oidc-username-claim=email \
    --extra-config=apiserver.oidc-groups-claim=groups
```

Enable ingress

```bash
minikube addons enable ingress
```

# Install ArgoCD
```bash
kubectl create namespace argocd

# use kustomize to deploy ArgoCD
kubectl apply -n argocd -k deploy/argocd

# OR

# use the manifest file to deploy ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/install.yaml
# Setup admin password to 'admin'
kubectl -n argocd patch secret argocd-secret -p '{"stringData": {
    "admin.password": "$2a$10$48U85bahwi7Vb4TQeFnvuOBLqhuDuHGvX22IRQYBwOZeCBoUhLV2K",
    "admin.passwordMtime": "'$(date +%FT%T%Z)'"
  }}'
```

Port forward to argocd server
```bash
kubectl -n argocd port-forward deployments/argocd-server 8080:8080
```

Login via CLI argocd
```bash
argocd login localhost:8080 --username admin --password admin --insecure
```

Add minikube cluster to argocd with name `wsp-dev-cluster` by cluster-admin role
```bash
argocd cluster add minikube --name wsp-dev-cluster --insecure
```

Add a dev cluster to argocd with name `wsp-dev-cluster` by a custom service account
```bash
KUBECONFIG="/home/nixer/.kube/config.k8s.dev:${KUBECONFIG}" 

argocd cluster add dev-admin@dev --name wsp-dev-cluster --insecure --service-account wsp-cd --system-namespace wsp-ns
```

Open ArgoCD UI in browser

http://localhost:8080

# Install Kyverno (optional)

```bash
kubectl create -f https://github.com/kyverno/kyverno/releases/download/v1.12.2/install.yaml
```