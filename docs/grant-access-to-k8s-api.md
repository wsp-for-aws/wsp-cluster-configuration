How to grant access to the Kubernetes API for a service account in a namespace
=

Generally, we use a `default` service account in each namespace to launch the pods. The service account has no
permissions to access the Kubernetes API. If you need to grant access to the Kubernetes API for the service account, you
can create a Role and RoleBinding for the service account in the namespace.

# Use case

The application `partner-backend` (with the service account `default`) requires the ability to create Kubernetes Jobs,
Pods, and ConfigMaps in the namespace `partner-cp`.

# Decision

To change the default permissions (the `default` service account cannot interact with the Kubernetes API),
we need to create a new Role with a custom set of permissions and bind it to the service account `default`.
Also, need to create a Cilium network policy to allow the application to interact Kubernetes API.
Prepare the following files in the `clusters/<cluster-name>/namespaces/<target-namespace>` directory.

- `role.partner-cp.yaml`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: partner-cp
rules:
  - apiGroups: [ "batch" ]
    resources: [ "jobs" ]
    verbs: [ "*" ]
  - apiGroups: [ "" ]
    resources: [ "pods", "configmaps" ]
    verbs: [ "*" ]
```

- `rolebinding.partner-cp.yaml`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: partner-cp
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: partner-cp
subjects:
  - kind: ServiceAccount
    name: default
```

- `cnp.partner-cp.yaml`:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: partner-api
spec:
  endpointSelector:
    matchLabels:
      io.cilium.k8s.policy.serviceaccount: default

  egress:
    - toEntities:
        - kube-apiserver
      toPorts:
        - ports:
            - port: "6443"
              protocol: TCP

  ingress: { }
```

- `kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: partner-cp

resources:
  - ../../default/
  - cnp.partner-cp.yaml
  - role.partner-cp.yaml
  - rolebinding.partner-cp.yaml
```

## Check result

```bash
kusomize build .
or
kubectl apply -k . --dry-run=client
```

And you can check the permissions for the service account in the namespace:

```bash
kubectl -n <target-namespace> auth can-i get pods --as=system:serviceaccount:<target-namespace>:default     # yes
kubectl -n <target-namespace> auth can-i get secrets --as=system:serviceaccount:<target-namespace>:default  # no
```

## Additional resources

We prepare an example resource that can demonstrate the ability to manage resources in your namespace.
[A job check access to the Kubernetes API](check-access-to-k8s-api.yaml) is a Job that checks the ability to
access the Kubernetes API. To check the access, you need to run the Job in the namespace.
