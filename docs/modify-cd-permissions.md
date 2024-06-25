How to modify the permissions that required to deploy an application
=

To deploy an application, you need to have the necessary permissions to manage the resources in the namespace.

Typical applications require the following permissions:

- Create, Read, Update, Delete (CRUD) for the following resources:
  - ConfigMap
  - Deployment / StatefulSet / CronJob / Job
  - Service / Ingress
  - PersistentVolumeClaim
  - PodDisruptionBudget / HorizontalPodAutoscaler
  - NetworkPolicy
- Restrictions:
  - Secrets - Cannot read (`get`). List, Create, Update, Delete are allowed.

We decided use one service account to deploy all client applications with the same permissions.
By default, this service account has no permissions to manage critical resources (security reasons) like as:
ServiceAccount, Role, RoleBinding, ClusterRole, ClusterRoleBinding, CiliumNetworkPolicy, etc.
WSP administrator can change the permission set of the service account via the `wsp-cd` ClusterRole 
(see `clusters/<cluster-name>/cluster-wide/clusterrole.wsp-cd.yaml`).

But if you need to grant access to manage some restricted resources for your application namespace,
you can create a new Role with a custom set of permissions and bind it to the service account.

The WSP CI/CD process deploys client applications using the `wsp-cd` service account from the `wsp-system` namespace.
This service account is used only for the deployment process. Not one can use it for other purposes.

# Detection of the problem

If the helm chart cannot create a resource, you can see the following error:

```bash
Error: UPGRADE FAILED: RoleBinding "deployer" is invalid: roleRef: Invalid value: rbac.RoleRef{APIGroup:"rbac.authorization.k8s.io", Kind:"Role", Name:"deployer"}: cannot change roleRef
```

This error occurs when the service account does not have the necessary permissions to manage the RoleBinding resource.

Also, you can check the permissions for the service account in the namespace:

```bash
kubectl -n partner-cp auth can-i create rolebinding --as=system:serviceaccount:wsp-system:wsp-cd  # no
```

# Use case

The helm char of the application `partner-cp` required to grant access to manage the ServiceAccount, Role, and
RoleBinding resources in the namespace `partner-cp`.

# Decision

We use the one service account `wsp-cd` from the namespace `wsp-system` to deploy client applications.
By default, the service account has no permissions to manage the ServiceAccount, Role, and RoleBinding resources.
You need to create a new Role with a custom set of permissions and bind it to the service account `wsp-cd`.
Prepare the following files in the `clusters/<cluster-name>/namespaces/application/<target-namespace>` directory.

- `role.deployer.yaml`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployer
rules:
  - apiGroups: [ "" ]
    resources: [ "serviceaccounts" ]
    verbs: [ "*" ]
  - apiGroups: [ "rbac.authorization.k8s.io" ]
    resources: [ "roles", "rolebindings" ]
    verbs: [ "*" ]
```

- `rolebinding.partner-cp.yaml`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deployer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: deployer
subjects:
  - kind: ServiceAccount
    name: wsp-cd
    namespace: wsp-system
```

- `kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: partner-cp

resources:
  - ../../../defaults/
  - role.deployer.yaml
  - rolebinding.deployer.yaml
```

## Check result

```bash
kustomize build clusters/<cluster-name>/namespaces/application/<target-namespace>/
# or
kubectl kustomize clusters/<cluster-name>/namespaces/application/<target-namespace>/
```

And you can check the permissions for the service account in the namespace:

```bash
kubectl -n partner-cp auth can-i create rolebinding --as=system:serviceaccount:wsp-system:wsp-cd     # yes
kubectl -n partner-cp auth can-i create clusterrole --as=system:serviceaccount:wsp-system:wsp-cd     # no
```

After applying the configuration, the service account `wsp-cd` can manage the ServiceAccount, Role, and RoleBinding
resources in the `partner-cp` namespace.
