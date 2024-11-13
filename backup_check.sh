#!/bin/bash

function startupChecks() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 dir_trabalho dir_backup"
        exit 1
    fi

    WORK_DIR=$1
    BACKUP_DIR=$2

    [[ -d "$WORK_DIR" ]] || { echo "Work directory $WORK_DIR does not exist!"; exit 1; }

    [[ -d "$BACKUP_DIR" ]] || { echo "Backup directory $BACKUP_DIR does not exist!"; exit 1; }
}

function main() {
    startupChecks "$@"

    
}

main "$@"