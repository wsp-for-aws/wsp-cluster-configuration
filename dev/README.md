# Developer information

- [Install dev instance of ArgoCD.](deploy/README.md)

# Configuration of ArgoCD server

## CLI tools

- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/binaries/) (optional)
- [argocd](https://argo-cd.readthedocs.io/en/stable/#quick-start) (optional)
- [kyverno](https://kyverno.io/docs/kyverno-cli/) (optional)
- [cilium](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#install-the-cilium-cli) (optional)

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