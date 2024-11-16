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


    if [[ "$CHECK" -eq 0 ]]; then
        WORK_DIR="$2"
        BACKUP_DIR="$3"
    else
        WORK_DIR="$1"
        BACKUP_DIR="$2"
    fi
    
    [[ -d "$WORK_DIR" ]] || { echo "Work directory $WORK_DIR does not exist!"; exit 1; }    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "mkdir $BACKUP_DIR"
        [[ "$CHECK" -eq 1 ]] && { mkdir -p "$BACKUP_DIR" ;}
    fi
}


# Criar um array com os nomes dos ficheiros do dir_backup e no loop ir apagando os ficheiros do array que existirem no dir_trabalho. Depois apagar os ficheiros do array que restarem.
function main() {
    shopt -s dotglob # Ver ficheiros escondidos

    startupChecks "$@"
    
    # Backup do diretório de trabalho
    for file in "$WORK_DIR"/*; do
        # O diretório de trabalho está vazio
        if [ "$file" = "$WORK_DIR"'/*' ]; then
            break
        fi

        if [[ -f $file ]]; then
            file_backup="${file//$WORK_DIR/$BACKUP_DIR}"
                
            if [[ -e $file_backup ]]; then
                if [[ ! -d $file_backup ]]; then # Ficheiro que existe no backup
                    date_backup=$(date -r "$file_backup" +%s)
                    date_file=$(date -r "$file" +%s)

                    if [[ date_backup -lt date_file ]]; then # Fazer o backup só se o ficheiro no backup é mais antigo
                        echo "cp -a $file $file_backup"
                        [[ "$CHECK" -eq 1 ]] && { cp -a $file $file_backup ;}
                        
                    fi
                fi
            else # Ficheiro não existente no backup
                echo "cp -a $file $file_backup"
                [[ "$CHECK" -eq 1 ]] && { cp -a $file $file_backup ;}
            fi
        fi
    done

    # Apagar os do backup que não existem no trabalho
    for file in "$BACKUP_DIR"/*; do
        # O diretório de backup está vazio
        if [ "$file" = "$BACKUP_DIR"'/*' ]; then
            break
        fi

        # Ignorar se for uma diretoria
        if [[ -d "$file" ]]; then
            continue
        fi

        file_work="${file//$BACKUP_DIR/$WORK_DIR}"

        if [[ ! -e "$file_work" ]]; then # Apagar ficheiro do backup se não existir no dir original
            echo "rm $file"
            [[ "$CHECK" -eq 1 ]] && { rm $file ;}
        fi
    done

    shopt -u dotglob # Parar de poder ver ficheiros escondidos
}


main "$@"
