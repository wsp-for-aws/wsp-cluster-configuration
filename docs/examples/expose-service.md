How to expose a service in a namespace
=

Use case:

- An application needs to expose a TCP/UDP port to the outside world.

We can recommend using the `Service` resource to expose the service in the namespace.
The `Service` resource must have special annotations to expose the service to the outside world.
We use aws-load-balancer-controller to create an AWS Application Load Balancer (ALB) for the service.

## Prerequisites

- the service name and the list of ports you want to expose

## Structure

- `svc.<service-name>.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: <app-service>
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-name: my-app-lb
    service.beta.kubernetes.io/aws-load-balancer-attributes: load_balancing.cross_zone.enabled=true
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: instance
    service.beta.kubernetes.io/aws-load-balancer-scheme: internal
    service.beta.kubernetes.io/aws-load-balancer-target-group-attributes: preserve_client_ip.enabled=false
    service.beta.kubernetes.io/aws-load-balancer-type: external
spec:
  type: LoadBalancer
  ports:
    - name: connect-port
      port: 9876
      targetPort: 9876
      protocol: TCP
    - name: queue-port
      port: 9000
      targetPort: 9000
      protocol: UDP
  selector:
    app: <app-name>  # wsp-app-name
...
```

The `Service` resource is an example of how to expose the service to the outside world.
We don't know a structure of your helm chart, so we show how you can expose your service.

- You can add more ports to the `ports` list.
- You can use one service for one deployment or multiple services for one deployment.
- Each such service (type: LoadBalancer) will be created as an AWS ALB and charged separately.

Also, need to patch 
the Kyverno policy `clusters/<cluster-name>/cluster-wide/kyverno-policies/no-loadbalancer-service.yaml` 
to allow the services with type: LoadBalancer.

```yaml
...
preconditions:
  - key: "{{request.object.metadata.namespace}}"
    operator: AnyNotIn
    value:
      - <target-namespace>
```
