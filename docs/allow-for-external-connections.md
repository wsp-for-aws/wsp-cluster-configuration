How to manage network interaction in/out of a namespace
=

To manage network interaction in/out of a namespace, we use the [Cilium](https://cilium.io/) eBPF-based networking
solution. Cilium provides a NetworkPolicy API that allows you to define how your application communicates with other
services.

# Use case

There is the application `partner-api` (from the namespace `partner-cp`) that needs
to interact with the external service `auth` (the namespace `global-auth`) on the port `5555`
and receive requests from the external service `billing-backend` (the namespace `billing-cp`) on the port `5080`.

## Decision

Usually, the default policy is to allow internal traffic between services in the same namespace and deny all other
traffic. To decide the task, you need to add an external Cilium network policy.
Prepare the following files in the `clusters/<cluster-name>/namespaces/<target-namespace>` directory.

- `cnp.partner-api.yaml`:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: partner-api
spec:
  endpointSelector:
    matchLabels:
      io.cilium.k8s.policy.serviceaccount: default

  egress:
    - toEndpoints:
        - matchLabels:
            app.kubernetes.io/name: auth
            app.kubernetes.io/namespace: global-auth
      toPorts:
        - ports:
            - port: "5555"
              protocol: TCP

  ingress:
    - fromEndpoints:
        - matchLabels:
            app.kubernetes.io/name: billing-backend
            app.kubernetes.io/namespace: billing-cp
      toPorts:
        - ports:
            - port: "5080"
              protocol: TCP
```

- `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: partner-cp
resources:
  - ../../default/
  - cnp.partner-api.yaml
```

### Check result

```bash
kustomize build .
or
kubectl apply -k . --dry-run=client
```
