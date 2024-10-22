#!/bin/bash


function startupChecks() {
    local errorMessage="Usage: $0 [-c] dir_trabalho dir_backup"
    if [[ $# -lt 2 ]]; then
        echo "$errorMessage"
        exit 1  
    fi
    
    if [[ $# -gt 3 ]] || ([[ $# -eq 3 ]] && [[ $1 != "-c" ]]); then
        echo "$errorMessage"
        exit 1  
    fi


    if [[ $# -eq 3 && $1 == "-c" ]]; then
        CHECK=0
    else
        CHECK=1
    fi

    #echo $CHECK


    if [[ "$CHECK" ]]; then
        WORK_DIR="$2"
        BACKUP_DIR="$3"
        [[ -d "$WORK_DIR" ]] || { echo "Work directory $WORK_DIR does not exist!"; exit 1; }    
        if [[ ! -d "$BACKUP_DIR" ]]; then
            echo "mkdir -p $BACKUP_DIR"
            if [[ "$CHECK" ]]; then
                mkdir -p "$BACKUP_DIR"
            fi
        fi          
    else
        echo AAAAA
        WORK_DIR="$1"
        BACKUP_DIR="$2"
        [[ -d "$WORK_DIR" ]] || { echo "Work directory $WORK_DIR does not exist!"; exit 1; }    
        if [[ ! -d "$BACKUP_DIR" ]]; then
            echo "mkdir -p $BACKUP_DIR"
            if [[ "$CHECK" ]]; then
                mkdir -p "$BACKUP_DIR"
            fi
        fi
    fi
}


# Criar um array com os nomes dos ficheiros do dir_backup e no loop ir apagando os ficheiros do array que existirem no dir_trabalho. Depois apagar os ficheiros do array que restarem.
function main() {
    startupChecks "$@"

    WORK_DIR;
    BACKUP_DIR;
    for i in "$(WORK_DIR/*)"; do
        echo $i
    done

    date -r joinWords.c +%s
    
}

main "$@"
