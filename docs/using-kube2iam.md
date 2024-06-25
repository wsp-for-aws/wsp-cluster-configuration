How to allow use kube2iam annotations in a namespaced resources
=

Sometimes you need to launch a pod needs to use an IAM role to access AWS resources.
We recommend you to use [kube2iam](https://github.com/jtblin/kube2iam) for this purpose.

## What is it kube2iam?

Kube2iam is a tool designed to manage AWS service access within a Kubernetes cluster. It facilitates the association of
different AWS IAM (Identity and Access Management) roles with pods in Kubernetes, negating the need to directly grant
these privileges to the pods themselves.

Here's how kube2iam operates:

1. **Deployment as a DaemonSet**: Kube2iam is typically deployed as a DaemonSet within the Kubernetes cluster. This
   ensures that an instance of kube2iam is running on each node of the cluster.

2. **Intercepting AWS Metadata Requests**: Pods in Kubernetes that require access to AWS services usually make calls to
   the AWS metadata service to obtain credentials. Kube2iam intercepts these requests before they reach the actual AWS
   metadata service.

3. **IAM Roles Configuration**: Kubernetes administrators can configure IAM roles and their associated access policies
   within AWS, then annotate pods within Kubernetes with special annotations that indicate which IAM role should be
   assumed. The Kubernetes administrator known which IAM role used by kube2iam in each cluster.

4. **Trust Relationship Configuration**: The IAM role that kube2iam runs under must have a trust relationship
   established in
   AWS. This trust relationship specifies that the kube2iam role can assume the IAM roles that the pods are annotated
   with. Configuration of this trust relationship is essential to allow kube2iam to function properly.

5. **Credential Provisioning**: When a pod makes a request to the metadata service, kube2iam determines the IAM role
   associated with that pod and temporarily provides the appropriate IAM credentials for use. Those credentials are
   provided to the requested API client in the pod and can be used to access AWS services.

This mechanism allows for a reduction in the need to store AWS credentials directly in containers or pods and provides a
more secure access management solution for AWS resources.

By default, the client pods cannot use the kube2iam annotations by security reasons.
We deny this via
[the Namespace Restriction](https://github.com/jtblin/kube2iam/blob/0.11.2/README.md#namespace-restrictions)
feature in kube2iam.
To use the kube2iam annotations, you need to allow this in the annotation `iam.amazonaws.com/allowed-roles` in the
namespace. This annotation should contain a list of IAM roles that can be used in the namespace.
Example for: `iam.amazonaws.com/allowed-roles: '["role-arn-one", "role-arn-two"]'  # Or any roles: '["*"]'`

Now if you try to use the kube2iam annotations in the pod without the `iam.amazonaws.com/allowed-roles` annotation
in the namespace, you will see the error like this (example aws-cli command):

```bash
...
role requested arn:aws:iam::123456789012:role/xxx not valid for namespace of pod at XX.XX.XX.XX with namespace xxx
```

You can use the `iam.amazonaws.com/external-id` annotation in the pod to specify the external-id for the IAM role.
This is useful if you want to have more control over the IAM role that the pod can assume.

# Use case

The application `report-portal` (from the namespace `report-portal`) needs to assume
the IAM role `arn:aws:iam::123456789098:role/report-portal` into the pod to access AWS resources.

# Decision

Kube2iam allows the use of IAM roles by pod annotations without storing AWS credentials in the pod.

To allow the use of the kube2iam annotations, we need to add
the annotation `iam.amazonaws.com/allowed-roles: '["arn:aws:iam::123456789098:role/report-portal"]'` to
the namespace `report-portal`.

Prepare the following files in the `clusters/<cluster-name>/namespaces/application/<target-namespace>` directory.

- `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: report-portal
resources:
  - ../../defaults

patches:
  - target:
      kind: Namespace
    patch: |-
      - op: add
        path: /metadata/annotations/iam.amazonaws.com~1allowed-roles
        value: '["arn:aws:iam::123456789098:role/report-portal"]'  # Value should be a string
```

OR

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: report-portal
resources:
  - ../../defaults

patches:
  - target:
      kind: Namespace
    patch: |-
      apiVersion: v1
      kind: Namespace
      metadata:
        name: report-portal
        annotations:
          iam.amazonaws.com/allowed-roles: '["arn:aws:iam::123456789098:role/report-portal"]'  # Value should be a string
```

Also, you should add a Cilium Network Policy to allow the pod to communicate with the AWS services.
More details you can find in the [Allow for external connections](./allow-for-external-connections.md) guide.

Here we provide an example of the Cilium Network Policy that allows the pod to communicate with the AWS services:

- `cnp.report-portal.yaml`:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: report-portal
spec:
  endpointSelector:
    matchLabels:
      io.cilium.k8s.policy.serviceaccount: default

  egress:
    - toFQDNs:
        - matchName: "*.amazonaws.com"
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
  ingress: { }
```

Do not forget to add the `cnp.report-portal.yaml` file to the `kustomization.yaml` file as a resource.

## Check result

```bash
kustomize build clusters/<cluster-name>/namespaces/application/<target-namespace>/
or
kubectl kustomize clusters/<cluster-name>/namespaces/application/<target-namespace>/
```

After applied this changes in a target cluster, a client pod (that stored in outside this repo) can use the kube2iam
annotations.
For example, the following pod spec allows to use the IAM role:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: report-portal
  namespace: report-portal
spec:
  selector:
    matchLabels:
      app: report-portal
  template:
    metadata:
      annotations:
        iam.amazonaws.com/role: arn:aws:iam::123456789098:role/report-portal
      labels:
        app: report-portal
    spec:
      containers:
        - name: rp-app
          image: rp-app:0.1.2
...
```

Please note that pod annotations in the resources like as Deployments, StatefulSets, DaemonSets, CronJobs, and Jobs
located in the `spec.template.metadata.annotations` section, not `metadata.annotaions`.

Simple way to check that the kube2iam annotations are allowed in the namespace is to use the following pod spec:

```bash
APP_NAMESPACE=report-portal
APP_ROLE=arn:aws:iam::123456789098:role/report-portal

cat <<EOF | kubectl -n "${APP_NAMESPACE}" apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: aws-test-pod
  annotations:
    iam.amazonaws.com/role: "${APP_ROLE}"
spec:
  containers:
    - name: aws
      image: amazon/aws-cli
      command: [ 'sh', '-c' ]
      args: [ 'aws sts get-caller-identity' ]
EOF
kubectl -n "${APP_NAMESPACE}" wait --for=condition=Ready pod/aws-test-pod
kubectl -n "${APP_NAMESPACE}" logs -f aws-test-pod
kubectl -n "${APP_NAMESPACE}" delete pod aws-test-pod
```
