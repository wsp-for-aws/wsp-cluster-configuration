#!/usr/bin/env bash

# This script allow to create mandatory files for a new namespace.
# Usage: ./tools/add_namespace.sh <CLUSTER_NAME> <NAMESPACE_NAME>

export CLUSTER_NAME="${1}"
export NAMESPACE_NAME="${2}"
if [ -z "${CLUSTER_NAME}" ] || [ -z "${NAMESPACE_NAME}" ]; then
    echo "Cluster name and namespace name are required"
    echo "Usage: ${0} <CLUSTER_NAME> <NAMESPACE_NAME>"
    exit 1
fi

TOOLS_DIR=$(realpath $(dirname "${0}"))
ROOT_DIR=$(dirname "${TOOLS_DIR}")
CLUSTER_DIR="${ROOT_DIR}/clusters/${CLUSTER_NAME}"
NAMESPACE_DIR="${CLUSTER_DIR}/namespaces/${NAMESPACE_NAME}"

if [ ! -d "${CLUSTER_DIR}" ]; then
    echo "Cluster ${CLUSTER_NAME} does not exist"
    echo "Please create the cluster first"
    exit 1
fi

# will be used a template directory from the target cluster if exists
if [ ! -d "${CLUSTER_DIR}/namespace_template" ]; then
    TEMPLATE_DIR="${TOOLS_DIR}/templates/namespace"
else
    TEMPLATE_DIR="${CLUSTER_DIR}/namespace_template"
fi
echo "Using template directory: ${TEMPLATE_DIR}"

# check if the namespace already exists
if [ -d "${NAMESPACE_DIR}" ]; then
    echo "Namespace ${NAMESPACE_NAME} already exists in cluster ${CLUSTER_NAME}"
    printf "Do you want to override it? [y/N]: "
    read -r OVERRIDE
    if [[ "${OVERRIDE}" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
        echo "Ok, overriding namespace ${NAMESPACE_NAME} in cluster ${CLUSTER_NAME}..."
    else
        echo "Exit" && exit 1
    fi
fi

# create the target directory
mkdir -p "${NAMESPACE_DIR}"

# Render the templates to the namespace directory
find "${TEMPLATE_DIR}" -type f -exec bash -c 'envsubst < "${0}" > "${0/$1/$2}"' {} "${TEMPLATE_DIR}" "${NAMESPACE_DIR}" \;

echo "Layout for the cluster ${CLUSTER_NAME} has been created in ${CLUSTER_DIR}"

echo "Don't forget to save the new configuration in the Git repository."
git status || true
