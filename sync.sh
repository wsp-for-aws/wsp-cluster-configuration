#!/bin/bash

SCRIPT_DIR=$(dirname $0)
KUBECONFIG="${KUBECONFIG:-~/.kube/config}"
TARGET_CLUSTER="${TARGET_CLUSTER:-dev}"
TARGET_CLUSTER_DIR="${SCRIPT_DIR}/clusters/${TARGET_CLUSTER}"
DRY_RUN="${DRY_RUN:-false}"
NAMESPACE_FILTER="${NAMESPACE_FILTER:-''}"
WSP_LABEL_NAME="${WSP_LABEL_NAME:-wsp.io/instance}"

usage() {
  local script_name=$(basename $0)
  echo "Usage: $script_name [options] [apply]"
  echo "Options:"
  echo "  --dry-run          - dry run mode"
  echo "  --kubeconfig       - path to the kubeconfig file"
  echo "  --target-cluster   - target cluster name"
  echo "  --namespace-filter - filter namespace by the comma-separated list of names"
  echo ""
  echo "Commands:"
  echo "  apply - apply resources to the target cluster"
  echo "  help - show this help message"
  echo ""
  echo "Example:"
  echo "  $script_name apply --target-cluster=dev"
  echo "  $script_name apply --kubeconfig=/path/to/kubeconfig --target-cluster=dev --namespace-filter=ns1,ns2"
  echo "  $script_name apply --kubeconfig=/path/to/kubeconfig --target-cluster=dev --namespace-filter=ns1,ns2 --dry-run"
}

# log message
logMsg() {
  echo -e "\e[32m$1\e[0m"
}

logVar() {
  local var_name=$1
  shift
  echo -e "\e[32m$var_name:\e[0m $*"
}

# log error
logError() {
  echo -e "\e[31m$1\e[0m"
}

# get all WSP namespaces
get_namespaces() {
  local escaped_label_name="${WSP_LABEL_NAME/\./\\.}"
  local jsonpath="{.items[?(@.metadata.labels.${escaped_label_name}=='true')].metadata.name}"

  kubectl get ns -o "jsonpath=${jsonpath}" | grep -v 'null' | grep -v 'system' | grep -v 'kube-'
}

# render all resources for the namespace
render_namespace_resources() {
  local ns=$1

  if [ ! -d "${ns}" ]; then
    # set namespace for kustomize
    kustomize edit set namespace "${ns}"
    # render all resources
    kustomize build . >"./build.${ns}.yaml"
  else
    pushd "${ns}" >/dev/null
      # render all resources
      kustomize build . >"../build.${ns}.yaml"
    popd >/dev/null
  fi
}

# apply all resources to the target cluster
apply_namespace_resources() {
  local ns=$1
  # apply rendered resources
  logMsg 'kubectl apply -f "./build.${ns}.yaml" --kubeconfig="${TARGET_CLUSTER}" --namespace="${ns}"'
#  kubectl apply -f "./build.${ns}.yaml" --kubeconfig="${TARGET_CLUSTER}" --namespace="${ns}"
}

# get the intersection of first array and another parameters
get_intersections_of_arrays() {
  local array1=($1)
  shift
  local array2=($@)
  local result=()

  for i in "${array1[@]}"; do
    for j in "${array2[@]}"; do
      if [ "$i" == "$j" ]; then
        result+=("$i")
      fi
    done
  done

  echo "${result[@]}"
}

# discover namespaces
discover_namespaces() {
  logVar "Target cluster" $TARGET_CLUSTER
  local namespaces=$(get_namespaces)
  logVar "Namespaces" $namespaces
}

# apply cluster wide resources to the target cluster
apply_cluster_resources() {
  logMsg "Target cluster: $TARGET_CLUSTER"
  pushd "${TARGET_CLUSTER_DIR}/cluster-wide/" >/dev/null
    # if not in dry run mode, apply resources
    if [ "$DRY_RUN" == "false" ]; then
      logMsg "kubectl apply -f '../build.cluster.yaml' --kubeconfig=${TARGET_CLUSTER}"
#      kubectl apply -f "../build.cluster.yaml" --kubeconfig="${TARGET_CLUSTER}"
    fi
  popd >/dev/null

  logMsg "Cluster wide resources applied!\n"
}

# apply resources per namespace to the target cluster
apply_ns_resources() {
  logMsg "Target cluster: $TARGET_CLUSTER"

  # get all namespaces
  local namespace=$(get_namespaces)

  logVar "All WSP Namespaces" "$namespace"

  # If the filter is not empty, filter namespace by the filter
  if [ -z "$NAMESPACE_FILTER" ]; then
    logVar "Namespace filter" "$NAMESPACE_FILTER"

    # get all namespaces from the filter string and split by comma
    IFS=',' read -r -a NAMESPACE_FILTER <<<"$NAMESPACE_FILTER"

    # get the intersection of the namespaces and the filter
    namespace=$(get_intersections_of_arrays "$namespace" "${NAMESPACE_FILTER[@]}" )
  else
    namespace=( "${namespace[@]}" )
  fi

  logVar "Namespaces" "${namespace[@]}"

  # if no namespaces found, exit
  if [ -z "$namespace" ]; then
    logError "No namespace found!"
    exit 1
  fi

  pushd "${TARGET_CLUSTER_DIR}/namespaces" >/dev/null

    for ns in $namespace; do
      render_namespace_resources "$ns"
    done

    # if not in dry run mode, apply resources
    if [ "$DRY_RUN" == "false" ]; then
      for ns in $namespace; do
        apply_namespace_resources "$ns"
      done
    fi

  popd >/dev/null
}

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

# Loop over all input arguments
for arg in "$@"; do
  case $arg in
  --dry-run)
    DRY_RUN=true
    shift
    ;;
  --kubeconfig=*)
    KUBECONFIG="${arg#*=}"
    shift
    ;;
  --target-cluster=*)
    TARGET_CLUSTER="${arg#*=}"
    shift
    ;;
  --namespace-filter=*)
    NAMESPACE_FILTER="${arg#*=}"
    shift
    ;;
  apply)
    logMsg "Applying resources to the target cluster"
    apply_cluster_resources
    apply_ns_resources
    ;;
  discover)
    logMsg "Discovering resources"
    discover_namespaces
    ;;
  help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
  esac
done

