#!/bin/bash

# Function to check if a command is available
command_exists() {
    command -v "$1" >/dev/null 2>&1
}
# Function to check if required commands are available
requirements_meet() {
    if ! command_exists ssh; then
        error "Error: ssh is not installed. Please install ssh and try again."
    fi
    # Check if kubectl is installed
    if ! command_exists kubectl; then
        error "Error: kubectl is not installed. Please install kubectl and try again."
    fi
}

install_dependencies() {
    info "Installing dependencies on all nodes"

    # Function to run the update, modify cmdline.txt, and set iptables alternatives on a single node
    update_node() {
        local node=$1
        if ! ssh pi@$node <<'EOF'; then
            sudo apt update && sudo apt upgrade -y
            if ! sudo grep -q 'cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory' /boot/cmdline.txt; then
                sudo sed -i '$s/$/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory/' /boot/cmdline.txt
                sudo reboot
            fi
            sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
            sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
            
EOF
            error "Error: Failed to install dependencies on node $node."
        fi
    }
    # Function to update /etc/hosts on worker nodes
    update_worker() {
        local node=$1
        if ! ssh pi@$node <<EOF; then
            if ! sudo grep -q '$masterip    pi-1' /etc/hosts; then
                echo "$masterip    pi-1" | sudo tee -a /etc/hosts
                sudo reboot
            fi            
EOF
            error "Error: Failed to update /etc/hosts on node $node."
        fi
    }

    # Run the update function for each node in the background
    workerspids=()
    for worker in "${workers[@]}"; do
        update_worker $worker &
        workerspids+=("$!")
    done
    for pid in "${workerspids[@]}"; do
        wait $pid || exit 1
    done

    pids=()
    for node in $master "${workers[@]}"; do
        update_node $node &
        pids+=("$!")
    done

    # Wait for all background jobs to finish and nodes to come back up
    for pid in "${pids[@]}"; do
        wait $pid || exit 1
    done
    sleep 30 # Wait for nodes to come back up
}
# Print error in red.
error() {
    echo -e "\033[31m✖ ERROR:\033[0m $1"
    exit 1
}

# Print an informational message in green
info() {
    echo -e "\033[32m➜ INFO:\033[0m $1"
}
