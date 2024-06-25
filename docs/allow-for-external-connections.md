How to manage network interaction in/out of a namespace
=

To manage network interaction in/out of a namespace, we use the [Cilium](https://cilium.io/) eBPF-based networking
solution. Cilium provides a NetworkPolicy API that allows you to define how your application communicates with other
services.

The default policy is to allow internal traffic between services in the same namespace and deny all other traffic.
If you need to allow or deny traffic to/from a specific service, allow connection to the Kubernetes API, or allow access
to/from an external API and the pod (e.g., AWS Metadata, AWS API, etc.), you can create a `CiliumNetworkPolicy` resource
in this repository.

## Detection of the problem

If the application needs to communicate with another service and is denied, you will see the following error:

```bash
curl: (7) Failed to connect to auth port 5555: Connection timed out
```

Cilium blocks the connection because there is no policy that allows the application to communicate with the `auth`
service. To discover the problem, you can use
the [Hubble](https://docs.cilium.io/en/stable/overview/intro/#what-is-hubble) tool, which provides a network visibility
solution for Kubernetes.
You can use the following command to check the network traffic:

```bash
kubectl -n kube-system port-forward svc/hubble-ui 8888:80
```

Open a browser and go to `http://localhost:8888`. You will see the Hubble UI.
You can use it to check the network traffic between the services.

## CiliumNetworkPolicy

The `CiliumNetworkPolicy` resource allows you to define how your application communicates with other services.

Schema of the CiliumNetworkPolicy:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: example-policy
  namespace: default
spec:
  # Selects all endpoints which should be subject to this rule.
  endpointSelector:
    matchLabels:
      io.cilium.k8s.policy.serviceaccount: example-application-serviceaccount

  # An endpoint is allowed to send traffic to another endpoint 
  # if at least one egress rule exists which selects the destination endpoint 
  # with the Endpoint Selector in the endpointSelector field.
  egress:
    # Rules for outgoing traffic based on entities.
    # More: https://docs.cilium.io/en/stable/security/policy/language/#entities-based
    - toEntities:
        # List of entities to which the traffic is allowed.
        - remote-node
        - kube-apiserver
      toPorts:
        # List of ports to which the traffic is allowed.
        - ports:
            # Port is an L4 port number. Required.
            - port: "6443"
              # Protocol is the L4 protocol. If omitted or empty, any protocol
              # Accepted values: "TCP", "UDP", "" / "ANY"
              protocol: TCP

    # An empty Endpoint Selector will select all egress endpoints from an endpoint based 
    # on the CiliumNetworkPolicy namespace (default by default).
    - toEndpoints:
        - { }

    # Use the simple egress rule to allow communication to endpoints with the label role=backend
    - toEndpoints:
        - matchLabels:
            role: backend
      toPorts:
        - ports:
            - port: "8000"
              protocol: TCP

  # An endpoint is allowed to receive traffic from another endpoint
  # if at least one ingress rule exists which selects the destination endpoint 
  # with the Endpoint Selector in the endpointSelector field.
  ingress:
    - fromEntities:
        - world
      fromPorts:
        - ports:
            - port: "80"
              protocol: TCP

    # An empty Endpoint Selector will select all endpoints, that will allow all ingress traffic to an endpoint may be done
    - fromEndpoints:
        - { }
```

Note that while the above examples allow all traffic to the endpoint, this does not mean that all endpoints are allowed
to send traffic to this endpoint per their policies.
In other words, policy must be configured on both sides (sender and receiver).

You can use the Cilium [NetworkPolicy Editor](https://editor.networkpolicy.io/) to create the policy.
The editor provides a visual way to create the policy and generates the YAML file.

We recommend using selectors powered by a service account to define the source and destination of the traffic:

```yaml
matchLabels:
  io.cilium.k8s.policy.serviceaccount: <app-sa>
```

It allows you to define the policy once and apply it to all pods with the same service account.

# Use case

A developer tried to deploy a new application that needs to communicate with external services.
The `partner-api` application (from the namespace `partner-cp`) needs to interact with the external service `auth`
(in the namespace `global-auth`) on port `5555` and receive requests from the external service `billing-backend`
(in the namespace `billing-cp`) on port `5080`.

## Decision

To decide the task, you need to add an external Cilium network policy. The policy should allow the application
`partner-api` to communicate with the service `auth` on the port `5555` and receive requests from the service
`billing-backend` on the port `5080`.
Prepare the following files in the `clusters/<cluster-name>/namespaces/application/<target-namespace>` directory.

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
            io.cilium.k8s.policy.serviceaccount: default
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
  - ../../../defaults/
  - cnp.partner-api.yaml
```

### Check result

```bash
kustomize build clusters/<cluster-name>/namespaces/application/<target-namespace>/
or
kubectl kustomize clusters/<cluster-name>/namespaces/application/<target-namespace>/
```

After applying the policy, the application `partner-api` can communicate with the service `auth` on the port `5555`
and receive requests from the service `billing-backend` on the port `5080`.
