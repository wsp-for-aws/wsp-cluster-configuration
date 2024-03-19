Kustomize
=

Kustomize is a tool to customize Kubernetes resources through a kustomization file. It allows you to define a set of
resources and apply customizations to them. The customizations can be applied to the resources in the form of patches,
replacements, and transformations.

Examples:

- How to define namespace in kustomization file via CLI

```bash
kustomize edit set namespace <namespace>
```

- How to replace a resource value in a kustomization file

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
patches:
  - target:
      version: v1
      kind: RoleBinding
      name: wsp-cd
    patch: |
      $patch: delete
      version: v1
      kind: RoleBinding
      metadata:
        name: wsp-cd
```