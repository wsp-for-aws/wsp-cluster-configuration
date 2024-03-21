#!/bin/bash
set -e

###
# This script adds a user to a Kubernetes cluster.
###

USERNAME=$1
NAMESPACE=$2
CLUSTER_NAME=$3
SA_NAMESPACE=${SA_NAMESPACE:-default}
FORCE=${FORCE:-false}

# Normalize the username
USERNAME=$(echo ${USERNAME} | tr '[:punct:]' '-')

ROOT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )
CLUSTER_DIR="${ROOT_DIR}/clusters/${CLUSTER_NAME}"
SA_NAME="user-${USERNAME}"
SA_NAMESPACE_DIR="${CLUSTER_DIR}/namespaces/${SA_NAMESPACE}"
SA_FILE_NAME="sa.${USERNAME}.yaml"

SA_FILE_PATH="${SA_NAMESPACE_DIR}/${SA_FILE_NAME}"

# check k8s resource in target cluster
if [ -f "${SA_FILE_PATH}" ]; then
  echo "Service account '${SA_NAME}' already exists in the '${SA_NAMESPACE}' namespace of ${CLUSTER_NAME} cluster."
  if [ "${FORCE}" = "true" ]; then
    echo "Force is set to true. Overwriting the existing service account."
  else
    exit 1
  fi
fi

# Create the directory if it does not exist
mkdir -p "${SA_NAMESPACE_DIR}"

# Create a service account
cat > "${SA_FILE_PATH}" <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${SA_NAME}
  namespace: ${SA_NAMESPACE}
---
apiVersion: v1
kind: Secret
metadata:
  name: token-for-${SA_NAME}
  namespace: ${SA_NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: ${SA_NAME}
type: kubernetes.io/service-account-token
EOF

echo ''
echo "Service account '${SA_NAME}' has been created in the '${SA_NAMESPACE}' namespace of ${CLUSTER_NAME} cluster."
echo "The file: ${SA_FILE_PATH}"
