How to expose an application service to the outside world
=

Most applications that run in Kubernetes used HTTP protocols to communicate with a client or initiate connection
himself.
However, some applications require exposing TCP or UDP ports to the outside world around existing webserver in the
Kubernetes cluster. Thous applications can be databases, message brokers, or other services that use TCP or UDP
protocols. To support such applications, we decided to use `aws-load-balancer-controller` to create
an AWS Application Load Balancer (ALB) for each Service with the type: `LoadBalancer`.

The [aws-load-balancer-controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.7/) is a controller
that manages Elastic Load Balancers for a Kubernetes cluster.
It satisfies Kubernetes Service objects of type `LoadBalancer` by provisioning Application Load Balancers.

The controller allow to configure the following annotations for the Service resource:

- `service.beta.kubernetes.io/aws-load-balancer-name` - The name of the load balancer.
- `service.beta.kubernetes.io/aws-load-balancer-nlb-target-type` - The target type of the load balancer (
  e.g., `instance` or
  `ip`).
- `service.beta.kubernetes.io/aws-load-balancer-scheme` - The scheme of the load balancer (e.g., `internal`
  or `internet-facing`).
- `service.beta.kubernetes.io/aws-load-balancer-type` - The type of the load balancer (e.g., `internal` or `external`).
- `service.beta.kubernetes.io/aws-load-balancer-target-group-attributes` - The target group attributes of the load
  balancer (e.g., `preserve_client_ip.enabled=true` or `stickiness.enabled=true,stickiness.type=source_ip`).
- `service.beta.kubernetes.io/aws-load-balancer-ssl-cert` - The SSL certificate ARN of the load balancer.

More information about the annotations you can find in
the [aws-load-balancer-controller documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.7/guide/service/annotations/).

Important note: Each such service (type: LoadBalancer) will be created as an AWS ALB and CHARGED separately.

To avoid unexpected charges, we decided to restrict the creation of the Service resource with the type: LoadBalancer
by using the Kyverno policy `clusters/<cluster-name>/cluster-wide/kyverno-policies/no-loadbalancer-service.yaml`.
When you need to create some Service resource with the type: LoadBalancer, you need to patch the Kyverno policy to
allow the services with the type `LoadBalancer` into your application namespace.

# Use case

The application `partner-api` from the namespace `partner-cp` needs to expose TCP port 8585 and UDP port 8586 to
the outside world.

# Decision

First, you need to patch the Kyverno
policy `clusters/<cluster-name>/cluster-wide/kyverno-policies/no-loadbalancer-service.yaml` to allow the creation of
the Service resource with the type: LoadBalancer in the namespace `partner-cp`.

```yaml
...
preconditions:
  - key: "{{request.object.metadata.namespace}}"
    operator: AnyNotIn
    value:
      # Namespaces that are allowed to use LoadBalancer services.
      ...
      - partner-cp
      ...
```

It is all that you need to do in the repository.
After applying the Kyverno policy, you can create the Service resource.

We expect that you will create the Service resource out of the repository.
For example, into your application repository with Helm chart.

The following example demonstrates how to expose the application `partner-api` to the outside world.

- `svc.partner-api.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: partner-api
  namespace: partner-cp
  annotations:
    # More information about the annotations you can find in the aws-load-balancer-controller documentation
    # https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.7/guide/service/annotations/
    service.beta.kubernetes.io/aws-load-balancer-name: partner-api
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: instance
    service.beta.kubernetes.io/aws-load-balancer-scheme: internal
    service.beta.kubernetes.io/aws-load-balancer-type: external
    # The client IP preservation is enabled (and can't be disabled) for instance and IP type target groups with UDP and TCP_UDP protocols.
    # ref: https://docs.aws.amazon.com/elasticloadbalancing/latest/network/load-balancer-target-groups.html#client-ip-preservation
    service.beta.kubernetes.io/aws-load-balancer-target-group-attributes: preserve_client_ip.enabled=true
spec:
  type: LoadBalancer
  ports:
    - name: tcp-port
      port: 8585
      protocol: TCP
      targetPort: 8585
    - name: udp-port
      port: 8586
      protocol: UDP
      targetPort: 8586
  selector:
    app: partner-api
...
```
