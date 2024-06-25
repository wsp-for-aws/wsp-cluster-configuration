#!/bin/bash

usage() {
  echo "This script prepares the required structure of directories and files for a new cluster or namespace."
  echo "The target path for the layout can be specified as an absolute or relative path."
  echo "Usage:"
  echo "  ${0} clusters/CLUSTER"
  echo "  ${0} clusters/CLUSTER/namespaces/application/NAMESPACE"
  echo "  ${0} clusters/CLUSTER/namespaces/system/NAMESPACE"
  echo ""
}

TARGET_PATH="${1}"
if [ -z "${TARGET_PATH}" ]; then
  usage
  echo "Error: Target path is required. Please specify a target path as an argument."
  exit 1
fi

TOOLS_DIR=$(dirname $(realpath "${0}"))
ROOT_DIR=$(dirname "${TOOLS_DIR}")
CURRENT_DIR=$(realpath $(pwd))

# Determine if the target directory exists or needs to be adjusted
TARGET_DIR=$(dirname "${TARGET_PATH}")
if [ ! -d "${TARGET_DIR}" ]; then
  if [ -d "${CURRENT_DIR}/${TARGET_DIR}" ]; then
    TARGET_PATH="${CURRENT_DIR}/${TARGET_PATH}"
  elif [ -d "${ROOT_DIR}/${TARGET_DIR}" ]; then
    TARGET_PATH="${ROOT_DIR}/${TARGET_PATH}"
  else
    echo "Error: Target directory '${TARGET_DIR}' does not exist in the current or root directories."
    exit 1
  fi
else
  TARGET_PATH=$(realpath "${TARGET_PATH}")
fi

RELATIVE_PATH=$(realpath --relative-to="${ROOT_DIR}" "${TARGET_PATH}")

if [ -e "${TARGET_PATH}" ]; then
  echo "Error: Target path '${RELATIVE_PATH}' already exists. Please provide a new target path."
  exit 1
fi

# Split the relative path into its components
IFS='/' read -r -a PARTS <<< "${RELATIVE_PATH}"

CLUSTERS="${PARTS[0]}"
CLUSTER="${PARTS[1]}"
NAMESPACES="${PARTS[2]}"
NAMESPACE="${PARTS[4]}"
DEEP_PATH="${#PARTS[@]}"

# Validate the provided path structure
if [ "${CLUSTERS}" != "clusters" ]; then
  usage
  echo "Error: Invalid path '${RELATIVE_PATH}'. The target path must locate under 'clusters/'."
  exit 1
fi

# Determine the action based on the path structure
if [ "${DEEP_PATH}" -eq 2 ]; then

  cp -r "${TOOLS_DIR}/templates/cluster" "${TARGET_PATH}"
  sed -i "s/__CLUSTER_NAME__/${CLUSTER}/g" "${TARGET_PATH}/application-set.yaml"
  echo "Layout for the cluster '${CLUSTER}' has been created in '${RELATIVE_PATH}'."

elif [ "${DEEP_PATH}" -eq 5 ] && [ "${NAMESPACES}" == "namespaces" ]; then

  cp -r "${TOOLS_DIR}/templates/namespace" "${TARGET_PATH}"
  sed -i "s/__NAMESPACE__/${NAMESPACE}/g" "${TARGET_PATH}/kustomization.yaml"
  echo "Layout for the namespace '${NAMESPACE}' has been created in '${RELATIVE_PATH}'."

else
  usage
  echo "Error: Invalid path '${RELATIVE_PATH}'. Please provide a valid cluster or namespace path."
  exit 1
fi
