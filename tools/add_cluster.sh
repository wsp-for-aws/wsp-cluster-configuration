#!/bin/bash

# This script allow to prepare the requires structure of directories and files for a new cluster.
# Usage: ./tools/add_cluster.sh <cluster_name>

export CLUSTER_NAME="${1}"
if [ -z "${CLUSTER_NAME}" ]; then
    echo "Cluster name is required"
    echo "Usage: ${0} <cluster_name>"
    exit 1
fi

TOOLS_DIR=$(realpath $(dirname "${0}"))
ROOT_DIR=$(dirname "${TOOLS_DIR}")
CLUSTER_DIR="${ROOT_DIR}/clusters/${CLUSTER_NAME}"
TEMPLATE_DIR="${TOOLS_DIR}/templates/cluster"

if [ -d "${CLUSTER_DIR}" ]; then
    echo "Cluster ${CLUSTER_NAME} already exists"
    printf "Do you want to override it? [y/N]: "
    read -r OVERRIDE
    if [[ "${OVERRIDE}" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
        echo "Ok, overriding cluster ${1}..."
    else
        echo "Exit" && exit 1
    fi
fi

# create the required directories
mkdir -p ${CLUSTER_DIR}/{cluster-wide/kyverno-policies,defaults,namespaces/wsp-ns}

# Render the templates to the cluster directory
find "${TEMPLATE_DIR}" -type f -exec bash -c 'envsubst < "${0}" > "${0/$1/$2}"' {} "${TEMPLATE_DIR}" "${CLUSTER_DIR}" \;

echo "Layout for the cluster ${CLUSTER_NAME} has been created in ${CLUSTER_DIR}"

echo "Don't forget to save the new configuration in the Git repository."
git status || true
