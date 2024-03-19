How to change default permissions set to deploy resources of a specific type
=

This manual will elucidate the process of modifying the preset permissions allocated for
the deployment of resources of a particular type.
This could include permissions such as managing CRD resources or handling certain Kubernetes resources.

## Prerequisites

- the directory for target NS (`clusters/<cluster-name>/namespaces/<target-namespace>`)
- know a permission you want to add or modify

## Structure

Prepare the following files in the `clusters/<cluster-name>/namespaces/<target-namespace>` directory.

### Create a new role with a custom set of permissions

- `role.<role-name>.yaml`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: <role-name>  # wsp-custom-cd
rules:
  - apiGroups: [ "cilium.io" ]
    resources: [ "ciliumnetworkpolicies" ]
    verbs: [ "*" ]
  - apiGroups: [ "" ]
    resources: [ "secrets", "configmaps", "serviceaccounts" ]
    verbs: [ "*" ]
```

- `rb.<role-binding-name>.yaml`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: <role-binding-name>  # wsp-viewer-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: <role-name>  # wsp-custom-cd
subjects:
  - kind: ServiceAccount
    name: wsp-cd
    namespace: wsp-ns
```

- `kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: <target-namespace>

resources:
  - ../../default/
  - role.<role-name>.yaml
  - rb.<role-binding-name>.yaml
```

## Check result

```bash
kusomize build .
or
kubectl apply -k . --dry-run=client
```
