WSP Cluster configuration
=

This repository contains the cluster infrastructure and requisite Kubernetes resources needs for client applications.
Throughout an application's lifecycle, a specific set of cluster resources must be consistently present.
For instance, with each application namespace, it is necessary to establish default resource limits, permissions,
network policies, and so forth ("defaults"). Moreover, we must have the capacity to modify these defaults (via an
approval process) for a specific application.

Both defaults and customisation strategies are stored in a Git repository, adhering to the principles of Infrastructure
as Code (IaC). Consequently, all resources will be automatically provisioned to WSP clusters.

We are not only required to add resources such as network policies or permissions but occasionally, we also need to
alter default resources like resource quota, role, and network policies. To address this issue, we have chosen to
utilise [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/), a tool that provides the flexibility to
describe naming in an imperative mode.

This tool boasts comprehensive documentation, enables debugging, and allows you to preview the outcome of its usage on
the developer's machine, eliminating the need for a cluster. Furthermore, its fundamental functionality is already
integrated into kubectl, affirming its popularity and relevance within the DevOps community.

## Prerequisites

- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/binaries/) (optional)

## Structure

The repository is structured as follows:

```bash
/clusters          # The root directory for all the target clusters
  /{cluster-name}  # dev, staging, prod, etc.
    /application-set.yaml  # The ArgoCD ApplicationSet that will deploy all resources in the cluster

    /cluster-wide           # Resources that are cluster-wide
      /{resource-name}.yaml # ClusterRole, ClusterRoleBinding, CiliumClusterwideNetworkPolicy, etc.
      /kustomization.yaml   # The kustomization file for the cluster-wide resources

    /defaults               # Default resources for all namespaces
      /{resource-name}.yaml # Namespace, ResourceQuote, CiliumNetworkPolicy, RoleBinding, etc.
      /kustomization.yaml   # The kustomization file required to import defaults as a base for the namespace resources

    /namespaces               # The directory of customization resources for all namespaces in the cluster
      /{namespace-name}       # wsp-app-ns, default, monitoring, etc.
        /{resource-name}.yaml # Override the default resources or/add new resources
        /kustomization.yaml   # The kustomization file for the namespace resources with rules to override the defaults
```

This structure allows you to manage cluster-wide resources, default resources (defaults), and application resources
in each target cluster. Each cluster can have different cluster-wide resources or defaults.

## Delivery process

The delivery process is based on the [ArgoCD](https://argoproj.github.io/argo-cd/) (ApplicationSet, Application)
and the GitOps principles.

The ArgoCD
[ApplicationSet](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/#the-applicationset-resource)
allow to monitor the changes in the repository and create several the ArgoCD Applications for a cluster.
One Application to deploy the cluster-wide resources and one by one Application for each application namespace.

The ArgoCD [Applications](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#applications)
in its turn will sync the all Kubernetes resources from the source directory to the cluster.
The ArgoCD Application support the kustomize (also Kubernetes manifests and Helm charts) as a source of the resources.

## How to add a new cluster

```bash
tools/add_cluster.sh <CLUSTER_NAME>
```

This command will create all the necessary directories and files for the new cluster according to
the structure described above.

One of created files is the ArgoCD ApplicationSet that should be deployed to a ArgoCD server.
To deploy the ArgoCD ApplicationSet to the server, you need to follow the instructions in the
[Deploy ArgoCD ApplicationSet](./docs/install-appsets.md) document.

In the ArgoCD server should be configured the connection to the Git repository with the cluster configuration.
All target clusters must have the following name format: `wsp-<CLUSTER_NAME>-cluster` (for example, `wsp-dev-cluster`)
and have the role `cluster-admin` to deploy the cluster-wide resources.

## How to add a new namespace to a cluster

When we have a target cluster you need to create a new namespace for an application.
One namespace can have one or more clients applications. It depends on the application architecture.

To add a new namespace to a cluster, you can use the following command:

```bash
tools/add_namespace.sh <CLUSTER_NAME> <NAMESPACE_NAME>
```

You receive a new kustomization file into the `clusters/{CLUSTER_NAME}/namespaces/{NAMESPACE_NAME}` directory.
If you want to change the default resource set that will be delivered to the application namespace, you can add new
resources, override or remove the default resources with help of the kustomization file.

All deployed resources will contain the following annotations in the metadata section:

- `wsp.io/part-of: wsp-cluster-configuration`

More information about the kustomization file can be found
[here](https://kubectl.docs.kubernetes.io/references/kustomize/).

## How to

We prepared several examples to show how to customize the application namespace.

- [Change the namespace resources limits.](./docs/examples/change-ns-resources-limits.md)
- [Modify the permissions that required to deploy an application.](./docs/examples/modify-permissions.md)
- [Grant access for a user / team to the application namespace using OIDC.](./docs/examples/grant-access-by-oidc.md)
- [Add a Cilium network policy.](./docs/examples/add-cnp.md)
- [Grant access a service account to the Kubernetes API.](./docs/examples/grant-access-to-k8s-api.md)
- [Assume an AWS role in the application namespace.](./docs/examples/using-kube2iam.md)
- [Expose the application service to the internet.](./docs/examples/expose-service.md)

## Additional information

- [Deploy ArgoCD ApplicationSet.](./docs/install-appsets.md)
- [Install dev instance of ArgoCD.](./deploy/README.md)
