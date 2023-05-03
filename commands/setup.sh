#!/bin/bash
source common/postgres.sh
source common/k3s.sh
source resources/cluster.config

cluster_init() {
    # Update and upgrade packages on all Raspberry Pis
    install_dependencies

    install_master
    MASTER_TOKEN=$(get_master_token)
    install_workers "$MASTER_TOKEN"
    install_postgres

    # Setup clsuter kubectl access
    setup_cluster_access

    # Create the namespace if it doesn't exist
    create_namespace "$namespace"
    # Provision POstgres superuser.
    if ! secret_exists "$secret_name" "$namespace"; then
        # Generate a random secure password
        PASSWORD=$(openssl rand -base64 32)
        # Create a PostgreSQL user with the generated password
        create_postgres_user "$pg_user" "$PASSWORD"

        # Create a Kubernetes secret with the required key-value pairs
        create_kubectl_secret "$secret_name" "$namespace" \
            "host" "$db_host" \
            "port" "$db_port" \
            "password" "$PASSWORD" \
            "user" "$pg_user"
    fi
    # Provision jwt secret.
    if ! secret_exists "$auth_secret_name" "$namespace"; then
        # Generate a random secure password
        JWT_TOKEN=$(openssl rand -base64 32)
        # Create a Kubernetes secret with the required key-value pairs
        create_kubectl_secret "$auth_secret_name" "$namespace" \
            "$auth_secret_key_name" "$JWT_TOKEN"
    fi

    if ! secret_exists "$docker_secret_name" "$namespace"; then
        kubectl create secret docker-registry "$docker_secret_name" \
            --docker-server=ghcr.io \
            --docker-username="$github_username" \
            --docker-password="$github_token" \
            -n "$namespace"
    fi
}
