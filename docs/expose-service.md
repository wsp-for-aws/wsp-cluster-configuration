How to expose a service in a namespace
=

# Use case

The application `partner-api` (from the namespace `partner-cp`) needs to
expose TCP port 8585 and UDP port 8586 to the outside world. These ports are used for receiving client's logs.

# Decision

We recommend using the `Service` resource to expose the application to the outside world.
The `Service` resource must have special annotations to expose the service to the outside world.
We use [aws-load-balancer-controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.7/)
to create an AWS [Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/) (ALB)
for each Service with the type: `LoadBalancer`.

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
      targetPort: 8585
      protocol: TCP
    - name: udp-port
      port: 8586
      targetPort: 8586
      protocol: UDP
  selector:
    app: partner-api
...
```

The `Service` resource demonstrates how to expose the application to the outside world.

Note:

- You can create one service to one application Deployment.
- Each such service (type: LoadBalancer) will be created as an AWS ALB and CHARGED separately.

Also, need to patch
the Kyverno policy `clusters/<cluster-name>/cluster-wide/kyverno-policies/no-loadbalancer-service.yaml`
to allow the services with the type `LoadBalancer` into the cluster.

```yaml
...
preconditions:
  - key: "{{request.object.metadata.namespace}}"
    operator: AnyNotIn
    value:
      ...
      - partner-cp
```
