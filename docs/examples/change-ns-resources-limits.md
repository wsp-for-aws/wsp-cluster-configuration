How to change the namespace resources limits
=

This guide will show you how to change (increase) the resource limits for a namespace.
We use the `ResourceQuota` resource to set the limits. More information about the `ResourceQuota` resource can be found
in the [Kubernetes documentation](https://kubernetes.io/docs/concepts/policy/resource-quotas/).
There is a default `ResourceQuota` resource and you can modify it with a kustomization file.

## Prerequisites

- the directory for target NS (`clusters/<cluster-name>/namespaces/<target-namespace>`)
- the resource limits you want to change

## Structure

Prepare the following files in the `clusters/<cluster-name>/namespaces/<target-namespace>` directory.

- `rq.wsp.yaml`:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: wsp
spec:
  hard:
    requests.cpu: "2"  # we change the default value from x to 2
    limits.cpu: "4"    # to 4
    limits.memory: 6Gi # to 6Gi
```

- `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: app
resources:
  - ../../default/

patches:
  - path: rq.wsp.yaml
    target:
      kind: ResourceQuota
      name: wsp
```

### Compact way

Elso we can use more compact way to change the `ResourceQuota` resource.
You need to manage only one file, but it is less readable and more complex to maintain.

- `kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: <target-namespace>
resources:
  - ../../default/

patches:
  - target:
      version: v1
      kind: ResourceQuota
      name: wsp
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

### Check result

```bash
kustomize build .
or
kubectl apply -k . --dry-run=client
```
