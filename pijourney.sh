#!/bin/bash
source common.sh
source cluster.config
source setup.sh

requirements_meet

export master
export masterip
export workers

# Map commands to their corresponding functions
if [ "$#" -ne 2 ]; then
    echo "Usage: pijourney <group> <command>"
    echo "Groups:"
    echo "  setup"
    exit 1
fi

case "$1" in
setup)
    case "$2" in
    cluster)
        cluster_init
        ;;
    *)
        echo "Usage: pijourney setup <command>"
        echo "Setup commands:"
        echo "  cluster - Initializes the cluster"
        exit 1
        ;;
    esac
    ;;
*)
    echo "Usage: pijourney <group> <command>"
    echo "Groups:"
    echo "  setup"
    exit 1
    ;;
esac
