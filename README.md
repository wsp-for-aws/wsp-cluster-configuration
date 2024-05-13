WSP Cluster configuration
=

This repository contains the necessary Kubernetes resources required for client applications.
Throughout an application's lifecycle, a certain set of cluster resources must be consistently available.
For instance, in each application namespace, it is essential to establish default resource limits, permissions,
network policies, and so on, collectively referred to as "defaults."
Additionally, there must be the ability to modify these defaults (through an approval process)
for individual applications.

# Delivery process

The cluster resources are stored in a Git repository, adhering to the principles of Infrastructure as Code (IaC).
All resources will be automatically provisioned to WSP clusters.
The delivery process relies on [ArgoCD](https://argoproj.github.io/argo-cd/) (ApplicationSet, Application).

The ArgoCD
[ApplicationSet](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/#the-applicationset-resource)
monitors changes in the repository and creates several ArgoCD Applications
for a cluster—one Application to deploy the cluster-wide resources and individual Applications
for each application namespace.
We prepare an `application-set.yaml` file for each cluster, which contains the configuration of the ApplicationSet
(see the structure below).

The ArgoCD [Applications](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#applications),
in turn, will sync all Kubernetes resources from the source directory to the cluster.
Each Application displays the status of the synchronization and the list of resources that will be deployed.
At this time, the ArgoCD Applications can create and modify resources in the cluster but not delete them.
This safety feature prevents accidental resource deletion. Resources created at one time but later removed
from the repository will be marked as `Orphaned` in the ArgoCD UI.

# Customization resources

We are required not only to add resources like network policies or permissions but also, occasionally,
to modify default resources such as resource quotas, namespace annotations, etc.
Important criteria for us include readability, simplicity, and flexibility in our scenarios.

To address this task, we decided to use [Kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/),
a tool that provides the desired flexibility and operates in an imperative mode.
This tool has comprehensive documentation, supports debugging, and allows developers to preview
outcomes before deployment. Its core functionality is integrated into kubectl, confirming its popularity and relevance
within the DevOps community.
The ArgoCD Application also supports Kustomize as a resource source.

The `kustomization.yaml` file is mandatory and must be present in the target resource directory.
This file contains all instructions for using, importing, and transforming Kubernetes resources.

## Enforcement policies

We use [Kyverno](https://kyverno.io/) to enforce policies in the Kubernetes cluster.
Kyverno allows us to validate, mutate, and generate resources.
We use it to control the creation of resources, enforce best practices, and ensure compliance with security policies.
For example, we can restrict the creation of resources with specific labels or annotations, enforce naming conventions,
etc.

## Network policies

To manage networking in and out of a namespace, we use the [Cilium](https://cilium.io/) eBPF-based networking solution.
Cilium provides a NetworkPolicy API that allows you to define how your application communicates with other services.
The Cilium network policies can be applied to the cluster-wide resources and the application namespaces.
Now we allow internal traffic between services in the same namespace and traffic between a service and
an ingress controller. The other traffic is denied by default.

## CLI tools

- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/binaries/) (optional)
- [argocd](https://argo-cd.readthedocs.io/en/stable/#quick-start) (optional)
- [kyverno](https://kyverno.io/docs/kyverno-cli/) (optional)
- [cilium](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#install-the-cilium-cli) (optional)

# Structure clusters and resources

The repository is structured as follows:

```
clusters/                            # The root directory for all the target clusters
└── {cluster-name}/                  # dev, staging, prod-eu, etc.
    ├── application-set.yaml         # The ArgoCD ApplicationSet that allow to deploy the cluster resources
    │
    ├── cluster-wide/                # The directory for cluster-wide resources
    │   ├── kyverno-policies/        # The Kyverno policies with the rules to enforce the WSP's policies
    │   ├── {resource-name}.yaml     # ClusterRole, ClusterRoleBinding, CiliumClusterwideNetworkPolicy, etc.
    │   └── kustomization.yaml       # The kustomization file for the cluster-wide resources
    │
    ├── defaults/                    # The directory for base resources that are common for all application namespaces
    │   ├── {resource-name}.yaml     # Namespace, ResourceQuote, CiliumNetworkPolicy, RoleBinding, etc.
    │   └── kustomization.yaml       # The kustomization file required to import the directory 'defaults' as a base for the namespace resources
    │
    └── namespaces/                  # The directory is a list of namespaces related to WSP and client applications
        └── {namespace-name}/        # app-name, monitoring, wsp-system, etc.
            ├── {resource-name}.yaml # Override the default resources or/add new resources
            └── kustomization.yaml   # The kustomization file for import defaults, rules to override the them and add new resources
```

This structure allows you to manage cluster-wide resources, defaults, and application resources
in each target cluster. Each cluster can have different cluster-wide resources or defaults.

## Naming conventions for resources

When you create a new resource (or patch for a resource), you should follow the naming conventions:

- File names should be in lowercase and use dots to separate parts of the name.
  The file name should consist of three parts: `{prefix}.{name}.{extension}`.
  For example, `ns.app-name.yaml`, `rolebinding.admin.yaml`, etc.

  * For prefixes, use the following rules:
    1. Use a short name of the resource type if it is a common resource (e.g., `ns` for Namespace).
       You can see shortnames in the output of the `kubectl api-resources` command.
    2. Otherwise, use the full name of the resource type (e.g., `job` for Job, `role` for Role, etc.).
  * For the name part, use the name of the resource.
  * And the extension should be `yaml`.
- Each file name of a resource should be unique within the directory.

# Configuration of ArgoCD server

## Access to this Git repository

The ArgoCD server should be configured to connect
to [the Git repository](https://argo-cd.readthedocs.io/en/stable/user-guide/private-repositories/#private-repositories).
This required to allow use this repository as a source of the ArgoCD ApplicationSet and Applications.

To add a new repository to the ArgoCD server, you can use the argocd CLI command:

```bash
argocd repo add {GIT_URL} --username {USERNAME} --password {PASSWORD}
```

## Access to target clusters

ArgoCD should have access to the
target [clusters](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-management/) and be able to deploy
the resources to the cluster.
To add a new cluster to the ArgoCD server, you need to provide the cluster name and a service account in the
target cluster that will be used to deploy the resources. The service account should have the `cluster-admin` role.

```bash
argocd cluster add {KUBECONFIG_CONTEXT_NAME} --name {CLUSTER_NAME} --serviceaccount argocd-manager --namespace kube-system
```

The CLI-command `argocd` can create a new service account in the target cluster
with the name `argocd-manager` in the `kube-system` namespace when you do not provide the service account name.

```bash
argocd cluster add {KUBECONFIG_CONTEXT_NAME} --name {CLUSTER_NAME}
```

# Generate resources for a new cluster

When you have a target Kubernetes cluster, you need to prepare WSP resources for that cluster.
These resources include: cluster-wide resources, defaults, and some WSP resources for it to work correctly.

## Preconditions

- The ArgoCD server should be configured to connect to the Git repository.
- The ArgoCD server should have access to the target cluster.

## Generate resources

To generate the resources, you can use the following command:

```bash
tools/add_cluster.sh {CLUSTER_NAME}
```

This command will create all the necessary directories and files for the new cluster according to
the structure described above.

## Save changes to the Git repository

After you have added the resources, you need to commit and push the changes to the Git repository.

## Add ApplicationSet to the ArgoCD

After generating the resources you receive the `clusters/{CLUSTER_NAME}/application-set.yaml` file.
This file contains the configuration of the ArgoCD ApplicationSet that will be used to deploy the cluster resources.
It is necessary to add this file to the ArgoCD server.

```bash
kubectl -n argocd apply -f clusters/{CLUSTER_NAME}/application-set.yaml
```

After successful applying the ApplicationSet, the ArgoCD server will create the Applications for the cluster.
You can see the list of the Applications and the status of the synchronization in the ArgoCD UI.

# Adding a new namespace to the cluster

When we have a target cluster you need to create a new namespace for each new application.
One namespace can have one or more clients applications. It depends on the application architecture.

To add a new namespace to a cluster, you can use the following command:

```bash
tools/add_namespace.sh {CLUSTER_NAME} {NAMESPACE_NAME}
```

You receive a new kustomization file into the `clusters/{CLUSTER_NAME}/namespaces/{NAMESPACE_NAME}` directory.
If you want to change the default resource set that will be delivered to the application namespace, you can add new
resources, override or remove the default resources with help of the `kustomization.yaml`.
More information about the kustomization file can be found
[here](https://kubectl.docs.kubernetes.io/references/kustomize/).

# How to

We have prepared some examples to resolve usual tasks that can be required during the application lifecycle:

- [Grant access for a user / a team to the application namespace using OIDC](./docs/grant-access-by-oidc.md)
- [Allow custom network connections outside the namespace](./docs/allow-for-external-connections.md)
- [Modify the namespace resources limits](./docs/change-ns-resources-limits.md)
- [Modify the permissions that required to deploy an application](./docs/modify-cd-permissions)
- [Grant access a service account to the Kubernetes API](./docs/grant-access-to-k8s-api.md)
- [Assume an AWS role in the application namespace](./docs/using-kube2iam.md)
- [Expose the application service to the internet](./docs/expose-service.md)

## Developer information

- [Install dev instance of ArgoCD.](./deploy/README.md)
