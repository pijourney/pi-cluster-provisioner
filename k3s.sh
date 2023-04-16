#!/bin/bash
source common.sh

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
