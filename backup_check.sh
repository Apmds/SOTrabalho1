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


function check() {

    local LOOP_DIR=$1
    local NOT_LOOP_DIR=$2
    
    for file in "$LOOP_DIR"/*; do
        if [[ ! -e "$file" ]]; then
            echo "Empty directory"
            break
        fi
        
        local file_other="${file%/*}"
        file_other="${file_other//$LOOP_DIR/$NOT_LOOP_DIR}"
        file_other="$file_other/${file##*/}"

        if [[ -d "$file" ]]; then
            if [[ -d "$file_other" ]]; then
                check "$file" "$file_other"
            else
                echo "Directory $file_other does not exist"
            fi
            continue
        fi

        if [[ ! -e "$file_other" ]]; then
            echo ""$file_other" does not exist"
            continue
        fi

        local hash=($(md5sum "$file"))
        local hash_other=($(md5sum "$file_other"))
        
        if [[ "$hash" != "$hash_other" ]]; then
            echo "$file" "$file_other" differ.
        fi
    done

}   

function main() {
    shopt -s dotglob

    startupChecks "$@"
    check "$@"

    shopt -u dotglob
}

main "$@"