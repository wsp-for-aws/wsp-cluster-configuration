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
   assumed.

4. **Credential Provisioning**: When a pod makes a request to the metadata service, kube2iam determines the IAM role
   associated with that pod and temporarily provides the appropriate IAM credentials for use.

This mechanism allows for a reduction in the need to store AWS credentials directly in containers or pods and provides a
more secure access management solution for AWS resources.

By default, clients pods can not use kube2iam annotations by security reasons. We deny this via a Kyverno policy.
All our policies are stored in the `clusters/<cluster-name>/cluster-wide/kyverno-policies/` directory.

One of the policies is `restrict-kube2iam-annotations.yaml` that denies the use of kube2iam annotations.
To allow this, you need to add a namespace and allowed role into the ConfigMap `kube2iam-access`
in the `wsp-system` namespace. The ConfigMap can contain multiple namespaces and a list of roles (one, multiple or '*').

# Use case

The application `report-portal` (from the namespace `report-portal`) needs to use
the IAM role `arn:aws:iam::123456789098:role/report-portal`.

# Decision

To allow the use of kube2iam annotations, we need to add the namespace `report-portal`
and the role `arn:aws:iam::123456789098:role/report-portal` into the ConfigMap `kube2iam-access`.

Add it to this file: `clusters/<cluster-name>/namespaces/wsp-system/kube2iam-access.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube2iam-access
data:
  allowFor: |
    ...
    'partner-cp': 
      - arn:aws:iam::123456789098:role/report-portal
```

After applied the ConfigMap, a client pod (that stored in outside this repo) can use the kube2iam annotations.
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
      labels:
        app: report-portal
      annotations:
        iam.amazonaws.com/role: arn:aws:iam::123456789098:role/report-portal
    spec:
      containers:
        - name: rp-app
          image: rp-app:latest
...
```

Please note that pod annotations in the resources like as Deployments, StatefulSets, DaemonSets, CronJobs, and Jobs
located in the `spec.template.metadata.annotations` section, not `metadata.annotaions`.
