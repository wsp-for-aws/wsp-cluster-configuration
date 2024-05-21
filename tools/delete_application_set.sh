#!/usr/bin/env bash

# This script allow to delete the requires structure of directories and files for a new cluster.
# Usage: ./tools/delete_application_set.sh <cluster_name>

export CLUSTER_NAME="${1}"
if [ -z "${CLUSTER_NAME}" ]; then
    echo "Cluster name is required"
    echo "Usage: ${0} <cluster_name>"
    exit 1
fi

export TOOLS_DIR=$(realpath $(dirname "${0}"))
export ROOT_DIR=$(dirname "${TOOLS_DIR}")
export CLUSTER_DIR="${ROOT_DIR}/clusters/${CLUSTER_NAME}"
export APPLICATION_SET_PATH="${CLUSTER_DIR}/application-set.yaml"

REMOVE_APPSET_ONLY=false  # --remove-appset-only
REMOVE_APPSET_AND_APPS=false  # --remove-appset-and-apps
REMOVE_ALL=false  # --remove-all

while [[ $# -gt 0 ]]; do
    case $1 in
        --remove-appset-only)
            REMOVE_APPSET_ONLY=true
            shift
            ;;
        --remove-appset-and-apps)
            REMOVE_APPSET_AND_APPS=true
            shift
            ;;
        --remove-all)
            REMOVE_ALL=true
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

if [ $REMOVE_ALL == $REMOVE_APPSET_ONLY ] && [ $REMOVE_ALL == $REMOVE_APPSET_AND_APPS ] && [ $REMOVE_ALL == false ]; then
    echo "You must specify one of the following options: --remove-appset-only, --remove-appset-and-apps, --remove-all"
    exit 1
fi

if [ $REMOVE_ALL == true ]; then
       echo "Removing the ArgoCD ApplicationSet, all applications, and all resources for the ${CLUSTER_NAME} cluster..."
       kubectl -n argocd delete appset -f "${APPLICATION_SET_PATH}"
       echo "ArgoCD ApplicationSet and all applications for the ${CLUSTER_NAME} cluster have been removed."
elif [ $REMOVE_APPSET_ONLY == true ]; then
        echo "Removing the ArgoCD ApplicationSet for the ${CLUSTER_NAME} cluster..."
        kubectl -n argocd delete appset -f "${APPLICATION_SET_PATH}" --cascade=orphan
        echo "ArgoCD ApplicationSet for the ${CLUSTER_NAME} cluster has been removed."
elif [ $REMOVE_APPSET_AND_APPS == true ]; then
    echo "Removing the ArgoCD ApplicationSet and all applications for the ${CLUSTER_NAME} cluster..."
    kubectl -n argocd delete appset -f "${APPLICATION_SET_PATH}" --cascade=orphan
    kubectl -n argocd delete applications -l "argocd.argoproj.io/instance=${CLUSTER_NAME}" --cascade=orphan
    echo "ArgoCD ApplicationSet and all applications for the ${CLUSTER_NAME} cluster have been removed."
else
    echo "Unknown error"
    exit 1
fi