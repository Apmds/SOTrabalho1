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

    num_files_work=$(ls -1q "$WORK_DIR" | wc -l)
    num_files_backup=$(ls -1q "$BACKUP_DIR" | wc -l)

    if [[ "$num_files_backup" -eq 0 && "$num_files_work" -eq 0 ]]; then
        exit 0
    fi

    LOOP_DIR="$BACKUP_DIR"
    NOT_LOOP_DIR="$WORK_DIR"

    if [[ "$num_files_backup" -eq 0 ]]; then
        LOOP_DIR="$WORK_DIR"
        NOT_LOOP_DIR="$BACKUP_DIR"
    fi

    for file in "$LOOP_DIR"/*; do
        if [[ ! -e "$file" ]]; then
            echo Diretório vazio.
            break
        fi
        
        file_other="${file%/*}"
        file_other="${file_other//$LOOP_DIR/$NOT_LOOP_DIR}"
        file_other="$file_other/${file##*/}"

        if [[ ! -e "$file_other" ]]; then
            echo "$file_other" não existe.
            continue
        fi

        # Dá sempre igual?? Afinal não
        hash=($(md5sum "$file"))
        hash_other=($(md5sum "$file_other"))
        
        if [[ "$hash" != "$hash_other" ]]; then
            echo "$file" "$file_other" differ.
        fi
    done
}

main "$@"