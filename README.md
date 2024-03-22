WSP Cluster infra for the WSP applications
=

This repository contains the infrastructure code and resources for the WSP applications.

All stored resources will be delivered to the WSP clusters automatically.

## Structure

The repository is structured as follows:

```bash
/clusters          # The root directory for all the clusters
  /{cluster-name}  # dev, staging, prod, etc.

    /cluster-wide           # Resources that are cluster-wide
      /{resource-name}.yaml # ClusterRole, ClusterRoleBinding, CiliumClusterwideNetworkPolicy, etc.   
      /kustomization.yaml   # The kustomization file for the cluster-wide resources

    /default                # Default resources that are namespace-wide
      /{resource-name}.yaml # Namespace, ResourceQuote, CiliumNetworkPolicy, Role, RoleBinding, etc.
      /kustomization.yaml   # The kustomization file for the default resources

    /namespaces               # The directory for the cluster namespaces resources
      /{namespace-name}       # wsp-app-ns, default, monitoring, etc.
        /{resource-name}.yaml # Override the default resources or add new resources
        /kustomization.yaml   # The kustomization file for the namespace resources with rules to override the default resources
```


## Add a new application namespace.

```bash
CLUSTER_NAME=dev
APP_NAMESPACE=app

mkdir -p clusters/${CLUSTER_NAME}/namespaces/${APP_NAMESPACE}
cd clusters/${CLUSTER_NAME}/namespaces/${APP_NAMESPACE}

kustomize create --resources ../../default/ --namespace ${APP_NAMESPACE}
```

You receive a new kustomization file `kustomization.yaml` with the following content.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../default/
namespace: app
```

More information about the kustomization file can be found [here](https://kubectl.docs.kubernetes.io/references/kustomize/).

If you want to add a custom resource to the application namespace you need to modify the `kustomization.yaml` file.

## How we can customize this application namespace?

### Overriding the wsp resource limits.

```bash
cat <<EOF > role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ResourceQuota
metadata:
  name: wsp
  namespace: app
spec:
  hard:
    requests.cpu: "2"  # we change the default value from 1 to 2
    limits.cpu: "4"    # from 2 to 4
    limits.memory: 6Gi # from 4Gi to 6Gi
EOF
```

In the `kustomization.yaml` file, we need to add the new resources as a patch.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../default/
namespace: app

patches:
  - target:
      kind: ResourceQuota
      name: wsp
    path: resource-quota.yaml
```

### Add additional cilium network policies.

```bash
cat <<EOF > network-policy.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: additional-network-policy
  namespace: app
spec:
  endpointSelector: {}
  ingress:
    - fromEndpoints:
        - matchLabels:
            app.kubernetes.io/component: api
EOF
```

In the `kustomization.yaml` file, we need to add this new resource.

app
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../default/
  - network-policy.yaml
namespace: app
```

### Change the default resource limits.

```bash
cat <<EOF > resource-limits.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: resource-limits
  namespace: app
spec:
    hard:
        requests.cpu: "3"
        requests.memory: 1Gi
        limits.cpu: "4"
        limits.memory: 2Gi
EOF
```

In the `kustomization.yaml` file, we need to add this new resource.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../default/
  - resource-limits.yaml
namespace: app
```


[Additional information](./docs/README.md)
