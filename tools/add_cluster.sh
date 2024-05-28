#!/usr/bin/env bash

# This script allow to prepare the requires structure of directories and files for a new cluster.
# Usage: ./tools/add_cluster.sh <cluster_name>
#
# Generally this script will create the following files based on the template directory:
# - tools/templates/clusters/*

export CLUSTER_NAME="${1}"
if [ -z "${CLUSTER_NAME}" ]; then
    echo "Cluster name is required"
    echo "Usage: ${0} <cluster_name>"
    exit 1
fi

export TOOLS_DIR=$(realpath $(dirname "${0}"))
export ROOT_DIR=$(dirname "${TOOLS_DIR}")
export CLUSTER_DIR="${ROOT_DIR}/clusters/${CLUSTER_NAME}"
export TEMPLATE_DIR="${TOOLS_DIR}/templates/cluster"

if [ -d "${CLUSTER_DIR}" ]; then
    echo "Cluster ${CLUSTER_NAME} already exists"
    printf "Do you want to override it? [y/N]: "
    read -r OVERRIDE
    if [[ "${OVERRIDE}" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
        echo "Ok, overriding cluster ${1}..."
    else
        echo "Exit" && exit 1
    fi
else
    echo "Creating cluster ${CLUSTER_NAME}..."
    mkdir -p "${CLUSTER_DIR}"
fi

# create the required directories for the cluster
for dir in $(find "${TEMPLATE_DIR}" -mindepth 1 -type d); do
    mkdir -p "${CLUSTER_DIR}/${dir#${TEMPLATE_DIR}/}"
done

# Render the templates to the cluster directory
find "${TEMPLATE_DIR}" -type f -exec bash -c 'echo "  ${0#"$TEMPLATE_DIR/"} - copied" ; envsubst < "${0}" > "${0/$1/$2}"' {} "${TEMPLATE_DIR}" "${CLUSTER_DIR}" \;

echo ""
echo "Layout for the cluster ${CLUSTER_NAME} has been created in ${CLUSTER_DIR}"

echo ""
echo "Don't forget to apply the ArgoCD ApplicationSet for the ${CLUSTER_NAME} cluster:"
echo "  kubectl -n argocd apply -f clusters/${CLUSTER_NAME}/application-set.yaml"
echo ""

echo "---"
echo "Don't forget to save the new configuration in the Git repository."
git status || true
