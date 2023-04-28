#!/bin/bash
source common/common.sh

check_k3s_installed() {
    local node=$1
    # Check if k3s is already installed on the master node
    if ssh pi@$node "command -v k3s &> /dev/null"; then
        info "k3s is already installed on the '$node' node."
        return
    fi
}
get_master_token() {
    ssh pi@$master "sudo cat /var/lib/rancher/k3s/server/node-token"
}

install_master() {
    if check_k3s_installed $master; then
        return
    fi
    # Install k3s on the master node
    echo "Installing k3s on master node"
    if ! ssh pi@$master "curl -sfL https://get.k3s.io | sh -"; then
        error "Error: Failed to install k3s on the master node. "
    fi
    info "Waiting for k3s server to start up..."
    sleep 1

}
install_workers() {
    local token=$1
    # Install k3s on the worker nodes
    for pi in "${workers[@]}"; do
        if check_k3s_installed $pi; then
            continue
        fi
        info "Installing k3s on worker node $pi"
        if ! ssh pi@$pi "curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE=644 K3S_URL=https://$master:6443 K3S_TOKEN=$token sh -"; then
            error "Error: Failed to install k3s on the worker node $pi. "
        fi
    done
}

# Reusable function to check if a Kubernetes secret exists
secret_exists() {
    local SECRET_NAME="$1"
    local NAMESPACE="$2"
    kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null
}

# Reusable function to create a Kubernetes secret
create_kubectl_secret() {
    local SECRET_NAME="$1"
    local NAMESPACE="$2"
    shift 2

    # Prepare secret key-value pairs
    local SECRET_DATA=()
    while [ "$#" -gt 0 ]; do
        SECRET_DATA+=("--from-literal=$1=$2")
        shift 2
    done

    # Create the Kubernetes secret with the provided key-value pairs
    kubectl create secret generic "$SECRET_NAME" \
        "${SECRET_DATA[@]}" \
        -n "$NAMESPACE"
}
setup_cluster_access() {
    # Replace these placeholders with appropriate values
    CLUSTER_NAME="pi"
    USER_NAME="pi"
    CONTEXT_NAME="pi"
    # Check if cluster access configuration already exists
    if kubectl config get-contexts | grep $CONTEXT_NAME >/dev/null 2>&1; then
        info "Cluster access configuration already exists. Skipping setup."
        return 0
    fi
    # Set up local kubectl access
    info "Setting up local kubectl access"
    ssh pi@$master "sudo cat /etc/rancher/k3s/k3s.yaml" >k3s.yaml
    sed -i "s/127.0.0.1/$master/g" k3s.yaml
    sed -i "s/default/pi/g" k3s.yaml

    # Extract cluster, context, and user from k3s.yaml
    SERVER=$(grep "server:" k3s.yaml | awk '{print $2}')
    CERTIFICATE_AUTHORITY_DATA=$(grep "certificate-authority-data:" k3s.yaml | awk '{print $2}')
    CLIENT_CERTIFICATE_DATA=$(grep "client-certificate-data:" k3s.yaml | awk '{print $2}')
    CLIENT_KEY_DATA=$(grep "client-key-data:" k3s.yaml | awk '{print $2}')

    # Add cluster, context, and user to the existing kubeconfig
    kubectl config set-cluster $CLUSTER_NAME --server=$SERVER
    kubectl config set clusters.$CLUSTER_NAME.certificate-authority-data $CERTIFICATE_AUTHORITY_DATA
    kubectl config set-credentials $USER_NAME
    kubectl config set users.$USER_NAME.client-certificate-data $CLIENT_CERTIFICATE_DATA
    kubectl config set users.$USER_NAME.client-key-data $CLIENT_KEY_DATA
    kubectl config set-context $CONTEXT_NAME --cluster="$CLUSTER_NAME" --user=$USER_NAME
    kubectl config use-context $CONTEXT_NAME

    # Set the new context
    kubectl config use-context pi

    # Cleanup
    rm k3s.yaml
}

create_namespace() {
    local NAMESPACE="$1"

    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        kubectl create namespace "$NAMESPACE"
    fi
}
