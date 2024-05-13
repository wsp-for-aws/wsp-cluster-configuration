How to change the namespace resources limits
=

We use the `ResourceQuota` resource to set the limits. More information about the `ResourceQuota` resource can be found
in the [Kubernetes documentation](https://kubernetes.io/docs/concepts/policy/resource-quotas/).
In each application namespace we added a default `ResourceQuota` resource, that can modified with the help of Kustomize.

# Use case

The application `report-portal` requires more resources than the default `ResourceQuota` resource provides.
We need to increase the limits for the `requests.cpu`, `limits.cpu`, and `limits.memory` fields.

# Decision

To change the `ResourceQuota` resource, we need to prepare a patch.
Prepare the following files in the `clusters/<cluster-name>/namespaces/<target-namespace>` directory.

- `qouta.wsp.yaml`:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ns-limits
spec:
  hard:
    # Default values: clusters/<cluster-name>/namespaces/<target-namespace>/default/quota.ns-limits.yaml
    # changing of the default value from X to the following values:
    requests.cpu: "2"
    limits.cpu: "4"
    limits.memory: 6Gi
```

- `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: report-portal
resources:
  - ../../default/

patches:
  - path: quota.ns-limits.yaml
    target:
      kind: ResourceQuota
      name: ns-limits
```

## Compact method

Elso we can use more compact method to change the `ResourceQuota` resource.
This method requires adding a `patches` section to the `kustomization.yaml` file.
You need to manage only one file, but it is less readable and more complex to maintain.

- `kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: report-portal
resources:
  - ../../default/

patches:
  - target:
      version: v1
      kind: ResourceQuota
      name: ns-limits
    patch: |-
      - op: replace
        path: /spec/hard/requests.cpu
        value: "2"
      - op: replace
        path: /spec/hard/limits.cpu
        value: "4"
      - op: replace
        path: /spec/hard/limits.memory
        value: "6Gi"
```

## Check result

```bash
kustomize build .
or
kubectl apply -k . --dry-run=client
```
