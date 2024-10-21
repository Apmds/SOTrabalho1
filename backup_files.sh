#!/bin/bash

function startupChecks() {
    errorMessage="Usage: [-c] dir_trabalho dir_backup"
    if [[ $# -lt 2 ]]; then
        echo "$errorMessage"
        exit 1  
    fi
    
    if [[ $# -gt 3 ]] || ([[ $# -eq 3 ]] && [[ $1 != "-c" ]]); then
        echo "$errorMessage"
        exit 1  
    fi


    if [[ $# -eq 3 && $1 == "-c" ]]; then
        CHECK=1
    else
        CHECK=0
    fi

    #echo $CHECK


    if [[ $CHECK -eq 1 ]]; then
        DIRTRABALHO="$2"
        DIRBACKUP="$3"
        [[ -d $DIRTRABALHO ]] || { echo "$errorMessage"; exit 1; }    
        [[ -d $DIRBACKUP ]] || { echo "$errorMessage"; exit 1; }           
    else
        DIRTRABALHO="$1"
        DIRBACKUP="$2"
        [[ -d $DIRTRABALHO ]] || { echo "$errorMessage"; exit 1; }    
        [[ -d $DIRBACKUP ]] || { echo "$errorMessage"; exit 1; }    
    fi
}


# Criar um array com os nomes dos ficheiros do dir_backup e no loop ir apagando os ficheiros do array que existirem no dir_trabalho. Depois apagar os ficheiros do array que restarem.
function main() {
    startupChecks "$@"

    DIRTRABALHO;
    DIRBACKUP;

    date -r joinWords.c +%s
    
}

main "$@"
