#!/bin/bash
source common/common.sh

update_postgresql_conf() {
    info "Updating the postgresql.conf file..."
    ssh pi@$master <<EOF
    sudo sed -i.bak -E \
        -e 's/^#?(max_connections[[:space:]]*=[[:space:]]*).*/\1 100/' \
        -e 's/^#?(shared_buffers[[:space:]]*=[[:space:]]*).*/\1 1GB/' \
        -e 's/^#?(effective_cache_size[[:space:]]*=[[:space:]]*).*/\1 3GB/' \
        -e 's/^#?(maintenance_work_mem[[:space:]]*=[[:space:]]*).*/\1 256MB/' \
        -e 's/^#?(checkpoint_completion_target[[:space:]]*=[[:space:]]*).*/\1 0.9/' \
        -e 's/^#?(wal_buffers[[:space:]]*=[[:space:]]*).*/\1 16MB/' \
        -e 's/^#?(default_statistics_target[[:space:]]*=[[:space:]]*).*/\1 100/' \
        -e 's/^#?(random_page_cost[[:space:]]*=[[:space:]]*).*/\1 4/' \
        -e 's/^#?(effective_io_concurrency[[:space:]]*=[[:space:]]*).*/\1 2/' \
        -e 's/^#?(work_mem[[:space:]]*=[[:space:]]*).*/\1 5242kB/' \
        -e 's/^#?(min_wal_size[[:space:]]*=[[:space:]]*).*/\1 1GB/' \
        -e 's/^#?(max_wal_size[[:space:]]*=[[:space:]]*).*/\1 4GB/' \
        -e 's/^#?(max_worker_processes[[:space:]]*=[[:space:]]*).*/\1 4/' \
        -e 's/^#?(max_parallel_workers_per_gather[[:space:]]*=[[:space:]]*).*/\1 2/' \
        -e 's/^#?(max_parallel_workers[[:space:]]*=[[:space:]]*).*/\1 4/' \
        -e 's/^#?(max_parallel_maintenance_workers[[:space:]]*=[[:space:]]*).*/\1 2/' \
        -e "s/^#?(listen_addresses[[:space:]]*=[[:space:]]*).*/\1 '*'/" \
        -e "s/^#?(shared_preload_libraries[[:space:]]*=[[:space:]]*).*/\1 'pg_stat_statements'/" \
        /etc/postgresql/*/main/postgresql.conf || {
        echo "Error: Failed to update the postgresql.conf file."
        exit 1
    }
EOF
}

install_postgres() {
    # Check if PostgreSQL is already installed
    if ssh pi@$master "command -v psql >/dev/null"; then
        info "PostgreSQL is already installed on the master node."
        return 0
    fi
    # Install and configure PostgreSQL on the master node
    info "Installing and configuring PostgreSQL on the master node"

    # Add the PostgreSQL repository and import the repository signing key
    ssh pi@$master "wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -"
    ssh pi@$master "echo 'deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main' | sudo tee /etc/apt/sources.list.d/pgdg.list"

    # Update package lists
    ssh pi@$master "sudo apt update"

    # Install PostgreSQL
    if ! ssh pi@$master "sudo apt install -y postgresql-15 postgresql-contrib-15"; then
        error "Error: Failed to install PostgreSQL on the master node. "
    fi

    # Enable and start PostgreSQL
    if ! ssh pi@$master "sudo systemctl enable postgresql"; then
        error "Error: Failed to enable PostgreSQL on the master node. "
    fi
    if ! ssh pi@$master "sudo systemctl start postgresql"; then
        error "Error: Failed to start PostgreSQL on the master node. "
    fi

    scp_output=$(scp resources/pg_hba.conf pi@$master:/tmp/ 2>&1)
    if [ $? -ne 0 ]; then
        info "Error: Failed to copy the pg_hba.conf file to the master node. "
        error "SCP Output: $scp_output"
    fi

    if ssh pi@$master "sudo cp /tmp/pg_hba.conf /etc/postgresql/15/main/pg_hba.conf"; then
        error "Error: Failed to copy the pg_hba.conf file to the master node. "
    fi

    # Update the required values in the postgresql.conf file
    update_postgresql_conf

    if ssh pi@$master "sudo systemctl restart postgresql"; then
        error "Error: Failed to restart PostgreSQL on the master node. "
    fi
}

create_postgres_user() {
    local PG_USER="$1"
    local PASSWORD="$2"

    # Create a user in PostgreSQL
    ssh pi@$master "psql -U postgres -c 'DO \$\$
    BEGIN
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '\''$PG_USER'\'') THEN
            ALTER USER \"$PG_USER\" WITH PASSWORD '\''$PASSWORD'\'';
        ELSE
            CREATE USER \"$PG_USER\" WITH PASSWORD '\''$PASSWORD'\'' SUPERUSER;
        END IF;
    END
    \$\$;'"
}
