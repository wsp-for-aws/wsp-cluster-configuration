How to grant access for a user / a team to a namespace using OIDC
=

This guide will show you how to grant access to a user or a team to a namespace using OIDC.
Read more about the OIDC authentication in
the [Kubernetes documentation](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens).

# Use case

Required grant access to the namespace 'report-portal' for the following subjects:

- the team qa-team `[Plesk] rnd-team-qa` should have viewer (read-only) access
- the users with the emails `john.doe@webpros.com` and `jane.doe@webpros.com` should have admin access.

# Decision

To grant access to the namespace, we create two RoleBindings for the `wsp-ns-viewer` and `wsp-ns-admin` ClusterRoles 
that ware prepared of WSP and add the required subjects to them.
Prepare the following files in the `clusters/<cluster-name>/namespaces/<target-namespace>` directory.

- `rolebinding.viewers.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: viewers
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: wsp-ns-viewer
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: Group
    name: '[Plesk] rnd-team-qa'
```

- `rolebinding.admins.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: admins
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: wsp-ns-admin
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: 'john.doe@webpros.com'
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: 'jone.doe@webpros.com'
```

If you need to add a custom role into the namespace, you can use the guide [Modify permissions](modify-cd-permissions).

- `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: <target-namespace>
resources:
  - ../../default/
  - rolebinding.admins.yaml
  - rolebinding.viewers.yaml
```

## Check result

```bash
kusomize build .
or
kubectl apply -k . --dry-run=client
```
