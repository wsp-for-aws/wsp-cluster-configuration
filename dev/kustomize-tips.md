Kustomize tips
=

[Kyverno](https://kyverno.io/) is a tool to customize Kubernetes resources through a kustomization file.
It allows you to define a set of resources and apply customizations to them.
The customizations can be applied to the resources in the form of patches, replacements, and transformations.

Examples:

- How to add labels to all resources created by kustomize

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: app

commonLabels:
  aaa: bbb

resources:
  - deployment.myapp.yaml
```

The kustomize commonLabels feature when used in a kustomization adds the specified label to all labels and
labelSelectors of all objects being deployed.

Result of rendering the kustomization file:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    aaa: bbb      # added by kustomize
  name: myapp
  namespace: app
spec:
  replicas: 1
  selector:
    matchLabels:
      aaa: bbb    # added by kustomize
      app: myapp
  template:
    metadata:
      labels:
        aaa: bbb  # added by kustomize
        app: myapp
    spec:
      containers:
      - image: nginx
        name: nginx
```

- How to define namespace in kustomization file via CLI

```bash
kustomize edit set namespace <namespace>
```

- How to replace a resource value in a kustomization file by json path

In chis example, we replace the namespace name in the `CiliumNetworkPolicy` resource
with the namespace name from the `Namespace` resource.

```yaml
replacements:
  - source:
      kind: Namespace
      fieldPath: metadata.name
    targets:
      - select:
          kind: CiliumNetworkPolicy
          name: allow-traffic-within-namespace
        fieldPaths:
          - spec.0.egress.0.toEndpoints.0.matchLabels.[k8s:io.kubernetes.pod.namespace]
          - spec.0.ingress.0.fromEndpoints.0.matchLabels.[k8s:io.kubernetes.pod.namespace]
```

- How to remove resource from a base in a kustomization file

```yaml
...
resources:
  - ../base/

patches:
  - target:
      version: v1
      kind: ResourceType
      name: resource-name
    patch: |
      $patch: delete
      version: v1
      kind: ResourceType
      metadata:
        name: resource-name
```
