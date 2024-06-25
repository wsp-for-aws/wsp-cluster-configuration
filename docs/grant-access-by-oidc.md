How to grant access for a user / a team to a namespace using OIDC
=

This guide will show you how to grant access for a user or a team to a namespace using OIDC.
Read more information about OIDC in
the [Kubernetes documentation](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens).

By default, the user authenticated via OIDC has no permissions in the cluster. The user should be granted permissions
explicitly.

The following groups have access to the WSP clusters:

- `[Plesk] rnd-team-devops` - a team of DevOps engineers with full access to all namespaces in the cluster to ensure
  stable operation of clusters and their components.
- `[Plesk] rnd-team-XXX` - can be a team of developers, QA engineers, or other specialists. The access level depends on
  the team's role and responsibilities. The team should have access only to the namespaces required for their work.
- also, there are individual users with specific permissions.

WSP uses the following roles to grant access to the application namespaces:

- `wsp-ns-viewer` - read-only access to the namespace (view resources, listen events, see logs, etc.). This role should
  be used for the users who need to monitor the namespace or discover the resources.
- `wsp-ns-admin` - full access to the namespace (create, update, delete namespaced resources). This role should be used
  with caution. It is recommended to use it only for the users who need to manage the namespace.

We not expect that you will create ClusterRoleBinding with this role, because it is not recommended to grant access to
the whole cluster for the users. If you need to grant access to the whole cluster, you should use a special ClusterRole
and ClusterRoleBinding in to the directory `clusters/<cluster-name>/cluster-wide`.

# Use case

Required to grant access to the namespace 'report-portal' for the following subjects:

- the QA team `[Plesk] rnd-team-qa` should have viewer (read-only) access
- the users with the emails `john.doe@webpros.com` and `jane.doe@webpros.com` should have full access to the namespace.

# Decision

To grant access to the namespace, we should have a Role (or a ClusterRole) and a RoleBinding.
We can use the following ClusterRoles for the namespace:

- `wsp-ns-viewer` - read-only access
- `wsp-ns-admin` - full access to the namespace.

To use these roles, you should create a RoleBinding with the required subjects.

Prepare the following files in the `clusters/<cluster-name>/namespaces/application/<target-namespace>` directory.

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

- `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: <target-namespace>
resources:
  - ../../../defaults/
  - rolebinding.admins.yaml
  - rolebinding.viewers.yaml
```

If you need to add a custom role into the namespace, you can use the guide [Modify permissions](modify-cd-permissions).

## Check result

```bash
kustomize build clusters/<cluster-name>/namespaces/application/<target-namespace>/
or
kubectl kustomize clusters/<cluster-name>/namespaces/application/<target-namespace>/
```

The correct configuration should be committed to the repository and applied to the target cluster.

After applying the configuration in to the target cluster, the permissions can be checked using the following command:

```bash
kubectl auth can-i get po --as-group <oidc_group> --as <full_name> --namespace <target-namespace>

# Examples:
kubectl auth can-i  get   po --as-group '[Plesk] rnd-team-qa' --as='User Name' --namespace 'report-portal'  #yes
kubectl auth can-i create po --as-group '[Plesk] rnd-team-qa' --as='User Name' --namespace 'report-portal'  #no

kubectl auth can-i  get   po --as 'john.doe@webpros.com' --namespace 'report-portal'  #yes
kubectl auth can-i create po --as 'john.doe@webpros.com' --namespace 'report-portal'  #yes
```
