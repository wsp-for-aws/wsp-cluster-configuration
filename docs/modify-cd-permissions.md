How to modify the permissions that required to deploy an application
=

This guide describes the process for changing the preset permissions allocated to deploy resources of a particular type.
This could include permissions such as managing CRD resources or handling certain Kubernetes resources.

# Use case

The helm char of the application `partner-cp` required to grant access to manage the ServiceAccount, Role, and
RoleBinding resources in the namespace `partner-cp`.

# Decision

We use the one service account `wsp-cd` from the namespace `wsp-system` to deploy client applications.
By default, the service account has no permissions to manage the ServiceAccount, Role, and RoleBinding resources.
You need to create a new Role with a custom set of permissions and bind it to the service account `wsp-cd`.
Prepare the following files in the `clusters/<cluster-name>/namespaces/<target-namespace>` directory.

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
  - ../../default/
  - role.deployer.yaml
  - rolebinding.deployer.yaml
```

## Check result

```bash
kusomize build .
or
kubectl apply -k . --dry-run=client
```

And you can check the permissions for the service account in the namespace:

```bash
kubectl -n partner-cp auth can-i create role --as=system:serviceaccount:wsp-system:wsp-cd            # yes
kubectl -n partner-cp auth can-i create clusterrole --as=system:serviceaccount:wsp-system:wsp-cd     # no
```
