#!/bin/bash
source postgres.sh
source k3s.sh

cluster_init() {
    # Update and upgrade packages on all Raspberry Pis
    install_dependencies

    install_master
    MASTER_TOKEN=$(get_master_token)
    install_workers "$MASTER_TOKEN"
    install_postgres

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

    # Replace these placeholders with appropriate values
    CLUSTER_NAME="pi"
    USER_NAME="pi"
    CONTEXT_NAME="pi"

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
