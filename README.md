# WSP cluster configuration

WSP is a Kubernetes-based hosting platform for applications. During the lifecycle of an application, there is a need
for additional cluster resources that, although not part of the application itself, play an important supporting role.
For example, it is essential to have default resource limits, permissions and network policies in each application
namespace.

This repository contains all such resources for all WSP clusters. Most are security or resource management related
policies, so changes require an approval. Having them in one Git repository allows to make any customization on a
per-cluster or per-application basis in a controlled and manageable way using standard GitOps practices.

# Under the hood

This section briefly describes the tools used in the repository and their purpose.

## ArgoCD

[ArgoCD](https://argo-cd.readthedocs.io/en/stable/) is in charge of the resource delivery process. It tracks changes
in the repository and automatically applies them to WSP clusters.

Specifically, [ArgoCD Applications](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#applications)
sync all Kubernetes resources from a specific source directory to a specific cluster, displaying both configuration
drift and synchronization status. For WSP clusters, we use one ArgoCD application for all cluster-wide resources and
one ArgoCD application for each individual application namespace. The process is fully automated using an
[ArgoCD ApplicationSet](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/#the-applicationset-resource),
which creates an ArgoCD application when a new application namespace is created.

## Kustomize

It is easy to add new resources to this repository to be delivered by ArgoCD, but sometimes we also need to be able to
modify existing ones (for example, change default resource limits for a specific application namespace).
To do this we use [Kustomize](https://kubectl.docs.kubernetes.io/references/kustomize/).

Kustomize provides a template-free way to customize resource configuration using patches to make specific modifications
of the same Kubernetes resources without touching them. The term *kustomization* refers to a kustomization.yaml file
containing a list of resources and patch rules to be applied. One kustomization can include the other one as a base and
modify resources as needed. Kustomize is built into kubectl and ArgoCD also has native support for it.

## Kyverno

[Kyverno](https://kyverno.io/) is a policy engine for Kubernetes. We use it to control resource creation and ensure
workload compliance with internally accepted policies (such as naming conventions or security rules) by blocking or
mutating API requests.

You can use Kyverno policies to validate, mutate, generate, and clean up Kubernetes resources. Moreover, policies
themselves are Kubernetes resources, so you can use familiar tools such as kubectl, git, and kustomize to manage them as
code. Specifically, we keep most of Kyverno policies as cluster-wide resources within the repository and deliver them
by ArgoCD. Kyverno CLI can be used to test policies before applying them to a cluster.

## Cilium

Just as we use Kyverno to enforce a policy, we rely on [Cilium](https://cilium.io/) to control how an application is
allowed to communicate with other services by defining its own ingress and egress rules.

Cilium is an open source, eBPF-based solution for providing, securing, and observing network connectivity between
workloads. Because eBPF runs inside the Linux kernel, Cilium policies can be applied and updated without any changes to
the application code or container configuration. We use Cilium CNI in all WSP clusters, so extended Cilium network
policies can be safely used to allow specific traffic both inside and outside an application namespace.

# Repository structure

The configuration within the repository is structured as follows:

```
clusters/                                # The root directory for all cluster configurations
└── {cluster-name}/                      # The specific cluster to be configured (dev, staging, internal, production)
    ├── application-set.yaml             # The ArgoCD ApplicationSet that automatically creates and deletes ArgoCD Applications for the cluster
    │
    ├── cluster-wide/                    # The directory for cluster-wide resources
    │   ├── kyverno-policies/            # Global WSP policies
    │   ├── {resource-name}.yaml         # ClusterRole, ClusterRoleBinding, CiliumClusterwideNetworkPolicy, etc.
    │   └── kustomization.yaml           # The kustomization for cluster-wide resources
    │
    ├── defaults/                        # The directory for resources common for all application namespaces
    │   ├── {resource-name}.yaml         # Namespace, RoleBinding, ResourceQuote, CiliumNetworkPolicy, etc.
    │   └── kustomization.yaml           # The kustomization for default resources (intended to be used as a base for namespaces)
    │
    └── namespaces/                      # The directory for namespace configurations
        ├── application/                 # The directory for application namespaces
        │   └── {namespace-name}/        # The specific application namespace (leika, lumin, report-portal)
        │       ├── {resource-name}.yaml # Any namespace-scoped resource (optional, if needed)
        │       └── kustomization.yaml   # The kustomization for namespace resources (can import defaults, patch them and/or add new resources)
        └── system/                      # The directory for system namespaces (kube-system, wsp-system, etc.)
            └── wsp-system/              # The system namespace with internal WSP configuration (required resources)
```

This structure allows you to manage cluster-wide resources, default resources, and application resources separately on
a per-cluster basis.

## Naming conventions

When you add a new resource to this repository please respect the following rules:
- File names must be in lowercase and match the `{resource-type}.{resource-name}.yaml` pattern
- Use the *short name* of the resource type if it has a common one, or the *name* otherwise (check `kubectl api-resources` output)
- Use hyphens as a word separator within the resource name

For example, `ns.report-portal.yaml`, `rolebinding.admin.yaml`.

# Usage

Note that all use cases described below assume that:
1. You already have an ArgoCD instance configured to track changes to this repository, and
2. A cluster you want to modify has already been added to the repository and the ArgoCD instance.

If this is not the case, and you want to add or remove a cluster or contribute to the code, please
refer to the [developer](dev/README.md) documentation instead.

## Add a new namespace

Before deploying an application to a WSP cluster, you must create a namespace for it. Depending on the architecture,
each application may have its own namespace, or multiple applications may share the same namespace. That is why we are
focusing on namespace configuration here.

To create a namespace, you need to add the corresponding resource, which will be delivered by ArgoCD, in the correct
path according to the [repository structure](#repository-structure). Typically, in addition to the namespace itself,
you also want to add some default resources to it. To reuse existing per-cluster defaults, you need to add an
appropriate kustomization. For this most typical case you can use the following helper script:

```bash
tools/generate_skeleton.sh clusters/{cluster-name}/namespaces/application/{namespace-name}
```

The script will generate a skeleton for you in the specified directory. 
To see the generated resources run the following command:

```bash
kubectl kustomize clusters/{cluster-name}/namespaces/application/{namespace-name}
```

Once you have reviewed the result and are satisfied with it, you should create a branch, commit the changes and open a
pull request. When this pull request is approved and merged, ArgoCD will notice the changes and apply them. The
ApplicationSet controller will create a new Application for the new directory, which in turn will create the namespace
itself and other resources in the cluster.

Note that you can use a similar flow for namespaces that already exist in the cluster (for example, deliver resources
to `kube-system`). In this case, you should not use the script, but manually create the directory and resources (except
for the namespace) in the repository. You can still use kustomize or just put raw manifests there (make sure they are
not partial and will pass the API validation).

## Modify resources

By committing to this repository, you can add, change, or remove both namespace-scoped and cluster-wide resources within
an existing cluster. Kustomize offers very flexible options for modifying resources. You can learn more in the official
[guide](https://kubectl.docs.kubernetes.io/references/kustomize/) or check out our own [recipes](dev/kustomize-tips.md).

To make it easier to get started, we have prepared guides for the most common tasks:

- [Grant access to an application namespace to a user or group using OIDC](docs/grant-access-by-oidc.md)
- [Change resource limits for an application namespace](docs/change-ns-resources-limits.md)
- [Allow custom network connections within the cluster](docs/allow-for-external-connections.md)
- [Allow to deploy an application with resources that require approval](docs/modify-cd-permissions)
- [Allow to assume an AWS role in an application namespace](docs/using-kube2iam.md)
- [Grant access to the Kubernetes API for an application](docs/grant-access-to-k8s-api.md)
- [Allow an application to expose TCP or UDP ports to the Internet](docs/expose-service.md)

## Delete a namespace

When you completely delete an application from a cluster, you also need to delete its namespace from this repository.
Once the directory is deleted, the ApplicationSet controller will delete the ArgoCD application, which in turn will
delete all the resources created by ArgoCD and the namespace itself at the end.

Note that if the namespace contains resources created externally (not by ArgoCD), the namespace will be preserved as
well as the ArgoCD application (in `ERROR` status). Other resources owned by ArgoCD will be deleted. In this case, it
is your responsibility to clean up the external resources and then delete the ArgoCD Application manually.