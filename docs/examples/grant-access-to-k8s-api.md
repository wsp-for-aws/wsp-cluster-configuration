How to grant access to the Kubernetes API for a service account in a namespace
=

Generally, we use a `default` service account in each namespace to launch the pods. The service account has no
permissions to access the Kubernetes API. If you need to grant access to the Kubernetes API for the service account, you
can create a Role and RoleBinding for the service account in the namespace.

## Prerequisites

- the directory for target NS (`clusters/<cluster-name>/namespaces/<target-namespace>`)
- the permissions you want to grant

## Structure

Prepare the following files in the `clusters/<cluster-name>/namespaces/<target-namespace>` directory.

- `role.<role-name>.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: <role-name>  # wsp-app-name
rules:
  - apiGroups: [ "" ]
    resources: [ "configmaps" ]
    verbs: [ "get", "list", "watch" ]
  - apiGroups: [ "" ]
    resources: [ "pods" ]
    verbs: [ "*" ]
  - apiGroups: [ "batch" ]
    resources: [ "jobs" ]
    verbs: [ "*" ]
```

The role allows:

- to read (get, list, and watch) the ConfigMaps
- all actions for the Pods
- all action for the Jobs.

Any another permissions are not allowed.

- `rb.<role-binding-name>.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: <role-binding-name>  # wsp-app-name
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: <role-name>  # wsp-app-name
subjects:
  # default service account in the namespace
  - kind: ServiceAccount
    name: default
  # and/or you can define this service account, that is used in the CI/CD pipeline when deploying the client application (helm chart)
  - kind: ServiceAccount
    name: wsp-cd
    namespace: wsp-ns
```

The role binding allows the service account(-s) to use the created role.

- `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../default/
  - role.<role-name>.yaml
  - rb.<role-binding-name>.yaml
namespace: <target-namespace>
```

### Check result

```bash
kustomize build .
or
kubectl apply -k . --dry-run=client
```

Also, you can check the permissions for the service account in the namespace:

```bash
kubectl -n <target-namespace> auth can-i get pods --as=system:serviceaccount:<target-namespace>:default
kubectl -n <target-namespace> auth can-i get pods --as=system:serviceaccount:wsp-ns:wsp-cd
```
