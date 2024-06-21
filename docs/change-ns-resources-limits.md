How to change the namespace resources limits
=

Kubernetes have two mechanisms to manage resources:
[ResourceQuota](https://kubernetes.io/docs/concepts/policy/resource-quotas/) and
[LimitRange](https://kubernetes.io/docs/concepts/policy/limit-range/).
The `ResourceQuota` resource is used to set the limits aggregated across all pods in the namespace,
while the `LimitRange` resource is used to set the limits for each pod and container.
Both resources are allow to control limits by CPU, memory, and number of objects.

We use the `ResourceQuota` resource to set control limits for the application namespace. WSP admins configure default
values for `ResourceQuota` in the `clusters/<cluster-name>/defaults/quota.ns-limits.yaml` file (individually for each
cluster). This `ResourceQuota` resource is included in the bundle of default resources for each application namespace.
Changing the default values is done using the kustomize tool and the `kustomization.yaml` file in the application
namespace.

What is
[Requests and Limits](https://cloud.google.com/blog/products/containers-kubernetes/kubernetes-best-practices-resource-requests-and-limits)
in Kubernetes?

- `requests` - The amount of resources guaranteed to a container.
- `limits` - The maximum amount of resources a container can use.

`requests` should be less than or equal to `limits`.
If `requests` is greater than `limits`, the pod will not start.
Also, a pod will not start if `requests` is greater than the available resources on the node.

Best practices for setting requests and limits:

- Set the `requests` and `limits` for CPU and memory.
- Set the `requests` and `limits` for the application based on the application requirements (use monitoring tools).
- To update the instance of your application, you must have a reserve of resources.

# Detection of the problem

There is an application report-portal in the report-portal namespace of a cluster. 
The application can be killed by the OOM-killer, or the application can be slow.

If your application restarts, you to check the status of the pod:

```
kubectl describe po app-xxx | grep -C2 'Reason:'
```

Available events related to the problem:

- `Warning` - `OOMKilling` - OOMKilled: Out of memory.
- `Warning` - `FailedCreate` - Error creating: pods "app-xxx" is forbidden: exceeded quota: ns-limits, requested:
  limits.memory=##Mi, used: limits.memory=##Mi, limited: limits.memory=##Gi
- `Warning` - `FailedScheduling` - 0/1 nodes are available: 1 Insufficient memory.

To understand the problem with the CPU throttling, you can use monitoring tools like Prometheus and Grafana.
If the CPU throttling is enabled, you can see the following metrics:

- `container_cpu_usage_seconds_total` - the total CPU usage of the container.
- `kube_pod_container_resource_limits_cpu_cores` - the CPU limit for the container.
- `kube_pod_container_resource_requests_cpu_cores` - the CPU request for the container.

# Use case

The application `report-portal` requires have restarts by the OOM-killer, and needs more resources.
We need to increase the limits to the following values:

- CPU requests - 2 CPU
- CPU limits - 4 CPU
- Memory limits - 6Gi

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
kustomize build clusters/<cluster-name>/namespaces/<target-namespace>/
or
kubectl kustomize clusters/<cluster-name>/namespaces/<target-namespace>/
```
