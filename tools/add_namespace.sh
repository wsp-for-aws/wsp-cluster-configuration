#!/usr/bin/env bash

# This script allow to create mandatory files for a new namespace.
# Usage: ./tools/add_namespace.sh <CLUSTER_NAME> <NAMESPACE_NAME>
#
# Generally this script will create the following files based on the template directory:
# - tools/templates/namespace/*

export CLUSTER_NAME="${1}"
export NAMESPACE_NAME="${2}"
if [ -z "${CLUSTER_NAME}" ] || [ -z "${NAMESPACE_NAME}" ]; then
    echo "Cluster name and namespace name are required"
    echo "Usage: ${0} <CLUSTER_NAME> <NAMESPACE_NAME>"
    exit 1
fi

export TOOLS_DIR=$(realpath $(dirname "${0}"))
export ROOT_DIR=$(dirname "${TOOLS_DIR}")
export CLUSTER_DIR="${ROOT_DIR}/clusters/${CLUSTER_NAME}"
export NAMESPACE_DIR="${CLUSTER_DIR}/namespaces/${NAMESPACE_NAME}"
export TEMPLATE_DIR="${TOOLS_DIR}/templates/namespace"

if [ ! -d "${CLUSTER_DIR}" ]; then
    echo "Cluster ${CLUSTER_NAME} does not exist."
    echo "Please create the cluster first."
    exit 1
fi

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
else
    echo "Creating namespace ${NAMESPACE_NAME} in cluster ${CLUSTER_NAME}..."
    mkdir -p "${NAMESPACE_DIR}"
fi

# create the target directory
for dir in $(find "${TEMPLATE_DIR}" -mindepth 1 -type d); do
    mkdir -p "${CLUSTER_DIR}/${dir#${TEMPLATE_DIR}/}"
done

# Render the templates to the namespace directory
find "${TEMPLATE_DIR}" -type f -exec bash -c 'echo "  ${0#"$TEMPLATE_DIR/"} - copied" ; envsubst < "${0}" > "${0/$1/$2}"' {} "${TEMPLATE_DIR}" "${NAMESPACE_DIR}" \;

echo ""
echo "Layout for the cluster ${CLUSTER_NAME} has been created in ${CLUSTER_DIR}"

echo "---"
echo "Don't forget to save the new configuration in the Git repository."
git status || true
