# Developer documentation

This is the documentation root for project maintainers and people who want to contribute to the code.

# Installation

In the project we use local kind clusters for development and testing. Follow this section to get your own developer
instance.

## Prerequisites

Before proceeding, please make sure that you have the following CLI installed:
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
- [argocd](https://argo-cd.readthedocs.io/en/stable/cli_installation/)

## Create a local cluster

```bash
kind create cluster --name=wsp --config=dev/deploy/kind.config

# Install ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait -n ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s
```

## Install required components

### ArgoCD

```bash
kubectl create namespace argocd
kubectl apply --kustomize dev/deploy
kubectl wait -n argocd --for=condition=ready --field-selector=status.phase!=Succeeded pod --all --timeout=60s
```

### Kyverno

```bash
kubectl create -f https://github.com/kyverno/kyverno/releases/download/v1.12.3/install.yaml
kubectl wait -n kyverno --for=condition=ready --field-selector=status.phase!=Succeeded pod --all --timeout=60s
```

### Cilium

TODO

## Configure the components

### ArgoCD

When the components are installed you should be able to access ArgoCD UI at https://argocd.localtest.me with
`admin:admin` credentials.

As this repository is [private](https://argo-cd.readthedocs.io/en/stable/user-guide/private-repositories/), we have to
authorize the local ArgoCD instance to access it. To do that, we need to register the repository with proper Git
credentials. We will use a personal HTTP access token for this purpose.

Go to https://git.plesk.tech/account -> "HTTP access tokens" -> "Create token":
- Token name: "argocd-dev"
- Project permissions: "Project read"
- Repository permissions: "Repository read"
- Expiry: "Do not expire"

Do not forget to press "Copy" before "Continue".

Although you can do most of the tasks (including registering a Git repository) via UI, you cannot manage application
sets there. So, let's configure CLI instead:

```bash
argocd login argocd.localtest.me --insecure --grpc-web --username=admin
```

Register the repository with your BitBucket username and the created token as a password:
```bash
argocd repo add https://git.plesk.tech/scm/wsp/wsp-cluster-configuration.git --username <firstname>.<lastname>
```

Congratulations! You have completed the installation section and can use your development instance.

# Usage

The repository is registered in the primary WSP ArgoCD instance, which tracks changes and syncs them to real clusters.
This remote instance is the main and the only "user" of the configuration stored here. To ensure that proposed
configuration changes are correct we use a local instance in the development flow. The flow itself and basic use cases
are covered below.

## Add a new cluster

Before proceeding, a cluster you want to add to ArgoCD should exist. You can test a new non-existent cluster locally
in advance and even merge these changes, but at the end of the day, you will have to add the real cluster to the WSP
ArgoCD instance. To create a new one, please refer the [guide](https://git.plesk.tech/projects/K8S/repos/clusters-config/browse/).

### Generate resources

First of all, we need to create required cluster resources according to the described
[structure](../README.md#repository-structure):

```bash
tools/genereate_skeleton.sh clusters/<cluster-name>
```

The script will create for you all the necessary directories and files. Feel free to modify the generated skeleton if
needed. You may also find useful our kustomization [tips](kustomize-tips.md).

Once you are done, create a branch, commit and push the changes.

TODO: update the branch in the application set to the current one before committing.

### Test the configuration locally

You can probably skip this section if you only used the helper script to create the skeleton for the new cluster. Keep 
reading if you have made any customizations that need to be tested or just want to get a feel for the development
process.

For testing purposes you can register the local kind cluster as the target one and see how your local ArgoCD will
process the changes in your branch. Use the local context name to reference the kind cluster instead of real one:

```bash
argocd cluster add kind-wsp --in-cluster --upsert --name ${CLUSTER_NAME}
```

This will create a service account within the kind cluster that ArgoCD will use to manage it. Now we can register the
application set generated for this cluster to see ArgoCD deployment in action:

```bash
kubectl apply -n argocd -f clusters/${CLUSTER_NAME}/application-set.yaml
```

After successfully applying the application set, the ArgoCD application-set controller  will create applications for the
cluster. You can see the list of them and the status of the synchronization at https://argocd.localtest.me or via CLI:

```bash
argocd app list
```

### Apply the configuration

The next step is to open a pull request from your branch to master. Once you have merged the changes you need to add
the real target cluster to the WSP ArgoCD instance.

Before proceeding, make sure:
1. You are currently using the proper kubeconfig for the cluster you want to add.
2. You have a context in your kubeconfig with privileged access to the cluster.

To add the cluster to ArgoCD run the following commands:
```bash
# Ensure that you are in the proper context and have a valid session
argocd login argocd.staging.wsp.plesk.tech --sso --grpc-web

argocd cluster add ${KUBECONFIG_CONTEXT_NAME} --name ${CLUSTER_NAME}
```

After that apply the application set:
```bash
kubectl apply -n argocd -f clusters/${CLUSTER_NAME}/application-set.yaml
```
TODO: update the branch in the application set to master

## Modify a cluster

### Development flow

First of all, you need to understand the rules:
- The application set controls only ArgoCD applications it owns. If you create an application manually or using CLI, it
will not be affected by any changes or removal of the application set.
- We intentionally use "create-delete" applicationsSync policy for the application set, so when you add a proper source
directory to Git (or remove it), the corresponding ArgoCD application will be created or deleted automatically.
- This means that if you simply delete an application using UI or CLI, it will be recreated by the application set
controller on the next sync. To delete an application, you have to deleted it from Git.
- Since the application set does not have "update" applicationsSync policy, any changes to the application set itself
do not affect existing ArgoCD applications, only new ones.
- This in turn means that you can modify ArgoCD applications through UI or CLI (for example, disable automated sync
while debugging). Such manual changes will not be rolled back automatically.

With this in mind, you have two options for development:
1. Iteratively commit changes to your branch, push them to the Git server and check results in ArgoCD.
2. Disable synchronization in ArgoCD and manually apply changes to the local cluster using kubectl.

In the first case, you can press "Sync/Refresh" button in UI to not wait for the polling interval after pushes or force
synchronization using CLI:
```bash
argocd app sync ${APP_NAME}
```

If you prefer the second option:
```bash
# Press "Details" -> "Disable Auto-Sync" to disable synchronization for an application in UI or use CLI:
argocd app set --sync-policy=manual ${APP_NAME}

# To apply changes in cluster-wide resources to the local cluster:
kubectl apply --kustomize clusters/${CLUSTER_NAME}/cluster-wide

# To apply changes in a specific namespace to the local cluster:
kubectl apply --kustomize clusters/${CLUSTER_NAME}/namespaces/${NAMESPACE}

# Commit all manual changes and re-enable synchronization:
argocd app set --sync-policy=automated ${APP_NAME}
argocd app sync ${APP_NAME}
```

Either way, once you are satisfied with results, rebase, re-push the branch and open a pull request.

### Modify an existing cluster

Typically, speaking of an existing cluster, you will probably do one of the following:
- Modify cluster defaults
- Add, modify or delete cluster-wide resources
- Add, modify or delete non-application namespaces (such as `wsp-system`)

In any case, to confirm that changes are as expected, use one of the commands:
```bash
kubectl kustomize clusters/${CLUSTER_NAME}/cluster-wide
kubectl kustomize clusters/${CLUSTER_NAME}/namespaces/${NAMESPACE}
```

Note that:
1. You should locally check changes to cluster-wide resources as they affect all namespaces, so ensure that all ArgoCD
applications are successfully deployed.
2. Similarly, pay attention when you change defaults. Some namespaces override them, some rely on them, so be sure
you understand the overall effect.

### Modify the cluster template

As an alternative to modifying an existing cluster, at some point you may want to rework the skeleton for new clusters.
To do that you need to adapt resources within `tools/templates/cluster` directory and run the generator script:
```bash
tools/generate_skeleton.sh clusters/test-cluster
```

Then you should create a branch, commit and push the configuration for the test cluster. After proper
[testing](#test-the-configuration-locally), you need to decide if the changes are for new clusters only or not.
If not, run the following command for each cluster you want to update and commit the difference:
```bash
diff -uprN clusters/<old_cluster> clusters/test-cluster
```

Once you are done, delete the configuration for the test cluster from your branch and open a pull request with the
remaining changes.

### Update the application set

Read on if you have changed the application set within the cluster template or have made some changes to the application
set of a specific cluster and want to apply those changes.

The key point is that we do not want to delete the application set along with all applications and workloads. Instead,
we simply want to update the applications according to the new application set template.

Make sure that you set the proper kubernetes context for the cluster and run the following commands:
```bash
kubectl delete -n argocd appset <appset-name> --cascade=orphan
kubectl apply -f clusters/${CLUSTER_NAME}/application-set.yaml
```

Note that all ArgoCD applications will be automatically updated, so any manual changes made to them (if any) will be
lost.

## Remove a cluster

Sometimes you may need to remove a cluster from ArgoCD. Depending on the scenario, you may or may not want to delete
all cluster configuration and workloads created by ArgoCD applications.

### Delete applied cluster configuration

In the simplest case, when you want to clean up everything created by ArgoCD within the cluster, all you need to do is
delete the application set:
```bash
kubectl delete -n argocd appset <appset-name>
```
This will cause the ArgoCD applications created by the application set to be deleted, which in turn will delete cascade
the application resources.

Wait until all ArgoCD applications are deleted. The operation will fail if there are externally created resources in
the namespaces created by ArgoCD. In this case, you will have to manually delete both the external resources and the
ArgoCD applications themselves.

You can now delete the cluster configuration from Git and then remove the cluster from ArgoCD:
```bash
argocd cluster rm <cluster-name>
```

Note that the in-cluster cluster cannot be removed with this, so if you are trying to clean up your local kind, just
rename it back:
```bash
argocd cluster set <cluster-name> --name in-cluster
```

### Keep applied cluster configuration

Things get more complicated if you want to disconnect ArgoCD from the cluster, but keep all the delivered configuration
and workloads. In this case, we cannot delete the application set directly, as this would delete cascade everything.

What we need is to delete the application set and the applications themselves, while preserving the remaining resources.
To do it we have two options:
1. Enable `preserveResourcesOnDeletion` syncPolicy for applications by [updating](#update-the-application-set) the application set.
2. Remove finalizers for all ArgoCD applications created from the application set template.

```bash
APPSET_NAME=<CLUSTER_APPSET_NAME> kubectl get applications -o json | \
  jq -r --arg APPSET_NAME "$APPSET_NAME" '.items[] | select(.metadata.ownerReferences[].name == $APPSET_NAME) | .metadata.name' | \
  while read app; do kubectl patch application "$app" --type='json' -p='[{"op": "remove", "path": "/metadata/finalizers"}]'; done
```
See https://argocd-applicationset.readthedocs.io/en/stable/Application-Deletion/ for details.

After that, you can delete the application set, delete the cluster configuration from Git, and then remove the cluster
from ArgoCD as described [above](#delete-applied-cluster-configuration).

# Upgrade

TODO: When the decision on how to deploy local clusters is made, add notes on reconfiguration and upgrades of the
components here.

# Cleanup

To completely remove the development instance from your local machine, use the following oneliner:
```bash
kind delete cluster --name wsp
```
