#!/bin/bash
set -e

# This script generates a kubeconfig file for a service account, which can be used to authenticate to a Kubernetes cluster.

USERNAME=$1
NAMESPACE=$2
SA_NAMESPACE=${3:-default}

#create a temporary directory to store the kubeconfig file
mkdir -p /tmp/kubeconfig

pushd /tmp/kubeconfig > /dev/null

#create a temporary kubeconfig file
cat > tmp-kubeconfig.yaml <<EOF
apiVersion: v1
kind: Config
clusters:
contexts:
current-context: default
users:
EOF

# Get cluster information of current context
cluster_name=$(kubectl config view --minify --output jsonpath='{.clusters[].name}')
cluster_server=$(kubectl config view --minify --output jsonpath='{..cluster.server}')
kubectl config view --minify --flatten --output jsonpath='{..cluster.certificate-authority-data}' | base64 -d > ca.crt

# Set the cluster server
kubectl --kubeconfig tmp-kubeconfig.yaml config set-cluster $cluster_name --server=$cluster_server --certificate-authority=ca.crt --embed-certs=true

# Get user information
user_name=${USERNAME:-test}
sa_name="user-${user_name}"

# Check the service account or exit
if ! kubectl get sa $sa_name --namespace $SA_NAMESPACE; then
  exit 1
fi

token=$(kubectl get sa $sa_name -o jsonpath={.secrets..name} --namespace $SA_NAMESPACE | xargs -n1 kubectl get secret --namespace $SA_NAMESPACE --output json | jq -r '.items[0].data.token' | base64 -d)

# Set the credentials
kubectl --kubeconfig tmp-kubeconfig.yaml config set-credentials $sa_name --token=$token

# Set the context
kubectl --kubeconfig tmp-kubeconfig.yaml config set-context $sa_name --cluster=$cluster_name --user=$sa_name --namespace=$NAMESPACE

# Use the context
kubectl --kubeconfig tmp-kubeconfig.yaml config use-context $sa_name

# check if the kubeconfig file is valid
kubectl --kubeconfig tmp-kubeconfig.yaml get pods
kubectl --kubeconfig tmp-kubeconfig.yaml config view

# Rename the kubeconfig file for the user
kubeconfig_file="$(pwd)/config.${user_name}.yaml"
mv tmp-kubeconfig.yaml $kubeconfig_file

# Finish
echo ''
echo "Congratulations!"
echo "Kubeconfig file is generated at ${kubeconfig_file}"
echo "You can use this file to connect to the cluster using kubectl by running:"
echo "  expose KUBECONFIG=${kubeconfig_file}"
echo ''
