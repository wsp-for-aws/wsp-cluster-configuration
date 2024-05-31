# Maintenance

Sometimes we need to recreate all Applications by a template of the Application Set or remove a cluster from ArgoCD.
We prepare a decision for several cases.

# Delete an Application Set without deleting the related Applications

**Use case**

We want to recreate an Application Set but do not want to delete the related Applications.

**Steps**:

1. Delete the Application Set without cascading deletion.

```bash
kubectl delete appset <appset-name> --cascade=orphan
```

2. After that, you can create this Application Set again if needed.

```bash
kubectl apply -f clusters/{CLUSTER_NAME}/application-set.yaml
```

Note: All related Applications will be aligned with the template of the Application Set (customisations will be lost).

# Clean up a cluster

**Use case**

We want to remove all deployed resources from a cluster.

**Steps**:

1. Delete the Application Set from the ArgoCD.

```bash
kubectl delete appset <appset-name>
```

2. Avoid destroying of the all related applications and their resources.

# Remove a cluster without deleting the deployed resources (forget about a cluster)

**Use case**

We want to remove an application from ArgoCD but all deployed resources should remain and not be deleted.

**Steps**:

1. Fist, need to delete finalizers from the ArgoCD Applications.

```bash
APPSET_NAME=XXX
kubectl get applications -o json \
  | jq -r --arg APPSET_NAME "$APPSET_NAME" '.items[] | select(.metadata.ownerReferences[].name == $APPSET_NAME) | .metadata.name' \
  | while read app; do kubectl patch application "$app" --type='json' -p='[{"op": "remove", "path": "/metadata/finalizers"}]'; done
```

2. After that, need to delete the ArgoCD Application Set.

```bash
kubectl delete appset $APPSET_NAME
```

# Deleting a cluster from ArgoCD

If you need to delete a cluster from ArgoCD, you can use ArgoCD UI or using the `argocd` CLI:

```bash
argocd cluster remove <cluster-name>
```

Note: Be careful! Do not delete the cluster if deployed resources exist in it.
