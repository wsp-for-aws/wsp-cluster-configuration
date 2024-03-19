How to grant access for a user / team to a namespace using OIDC
=

This guide will show you how to grant access to a user or team to a namespace using OIDC.
Read more about the OIDC authentication in the [Kubernetes documentation](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens).

## Prerequisites

- the directory for target NS (`clusters/<cluster-name>/namespaces/<target-namespace>`)
- known target the Role or the ClusterRole
- known the OIDC user or group name

## Structure

Prepare the following files in the `clusters/<cluster-name>/namespaces/<target-namespace>` directory.

- `rb.<role-binding-name>.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: <role-binding-name>  # wsp-viewer-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: <role-name>  # wsp-viewer-role
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: <user-name>  # john.doe@domain.tld
  - apiGroup: rbac.authorization.k8s.io
    kind: Group
    name: <group-name>  # '[Org] rnd-team-name'
```

- `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: <target-namespace>
resources:
  - ../../default/
  - rb.<role-binding-name>.yaml
```

#### Check result

```bash
kusomize build .
or
kubectl apply -k . --dry-run=client
```

NOTE: If you need to add a custom role into the namespace, you can use the guide [Modify permissions](modify-permissions.md).
```
