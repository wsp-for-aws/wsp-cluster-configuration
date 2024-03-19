How to manage network interaction in/out of a namespace
=

This guide will show you how to add a [Cilium](https://cilium.io/) network policy to manage network interaction in/out of a namespace.

## Prerequisites

- the directory for target NS (`clusters/<cluster-name>/namespaces/<target-namespace>`)
- know how to write a [Cilium network policy](https://docs.cilium.io/en/stable/security/policy/kubernetes/)
- you know additional information about target applications (labels, ports, protocols, sa, etc.)

## Structure

Prepare the following files in the `clusters/<cluster-name>/namespaces/<target-namespace>` directory.

- `cnp.<network-policy-name>.yaml`:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: external
spec:
  endpointSelector:
    matchLabels:
      io.cilium.k8s.policy.serviceaccount: default

  ingress:
    - fromEndpoints:
        - matchLabels:
            app.kubernetes.io/name: app-agent
      toPorts:
        - ports:
            - port: "5555"
              protocol: TCP

  egress:
    - toEndpoints:
        - matchLabels:
            app.kubernetes.io/name: app-api
    - toEntries:
        - host
        - kube-apiserver
      toPorts:
        - ports:
            - port: "5080"
              protocol: TCP
```

- `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../default/
  - cnp.<network-policy-name>.yaml
namespace: <target-namespace>
```

### Check result

```bash
kustomize build .
or
kubectl apply -k . --dry-run=client
```
