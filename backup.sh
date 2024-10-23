#!/bin/bash

function throwError() {
    echo "$errorMessage"
    exit 1
}

function startupChecks() {
    local errorMessage="Usage: $0 [-c] [-b tfile] [-r regexpr] dir_trabalho dir_backup"
    local regex='(-c)?\s*(-b\s+\S+)?\s*(-r\s+\S+)?\s+\S+\s+\S+'

    if [[ $# -lt 2 ]]; then
        throwError
    fi
    
    local args=("$@")
    CHECK=1
    IGNORE=1
    REGEX=1

    if [[ $# -ne 2 ]]; then
        for ((i=0; i < $#; i++)); do
            #echo "${args[$i]}"
            if [[ ${args[$i]} == "-c" ]]; then
                CHECK=0
                continue
            fi
            if [[ ${args[$i]} == "-b" ]]; then
                IGNORE=0
                if [[ $(($i+1)) > $(($#-3)) ]]; then
                    throwError
                fi
                if [[ -f ${args[$(($i+1))]} ]]; then
                    IGNORE_FILE=${args[$(($i+1))]}
                    ((i++))
                    continue
                else
                    throwError     # Ficheiro inválido
                fi
            fi
            if [[ ${args[$i]} == "-r" ]]; then
                REGEX=0
                
                if [[ $(($i+1)) > $(($#-3)) ]]; then
                    throwError
                fi
                EXPRESSION=${args[$(($i+1))]}
                ((i++))
                continue
            fi
        done
    fi

    # Obter nomes dos ficheiros ignorados
    if [[ $IGNORE -eq 0 ]]; then
        declare -g -A IGNORED_FILES
        while IFS= read -r line; do
            IGNORED_FILES["$line"]=0
        done < <(grep "" $IGNORE_FILE)
    fi
    
    # Obter nomes dos diretórios
    WORK_DIR=${args[(($#-2))]}
    BACKUP_DIR=${args[(($#-1))]}
    
    # Verificação dos diretórios
    [[ -d "$WORK_DIR" ]] || { echo "Work directory $WORK_DIR does not exist!"; exit 1; }
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "mkdir -p $BACKUP_DIR"
        [[ "$CHECK" -eq 1 ]] && { mkdir -p "$BACKUP_DIR" ;}
    fi
}


# Criar um array com os nomes dos ficheiros do dir_backup e no loop ir apagando os ficheiros do array que existirem no dir_trabalho. Depois apagar os ficheiros do array que restarem.
function main() {
    startupChecks "$@"
    #echo "Ignored files: ${IGNORED_FILES[@]}"
    #echo "$EXPRESSION"

    for file in "$WORK_DIR"/*; do
        
        #Ignorar ficheiros
        #Se eles tiverem no backup têm de ser apagados?? 
        if [[ "$IGNORE" -eq 0 ]]; then
            if [[ "${IGNORED_FILES[${file##*/}]}" ]]; then
                echo "Ignoring $file"
                continue
            fi
        fi
        
        # if [[ "$IGNORE" -eq 0 ]]; then
        #     ignore_flag=1
        #     for ig_file in "${IGNORED_FILES[@]}"; do
        #         # Os ficheiros a ignorar só têm o basepath??
        #         if [[ "${file##*/}" == "$ig_file" ]]; then
        #             ignore_flag=0
        #             break
        #         fi
        #     done
        #     if [[ "$ignore_flag" -eq 0 ]]; then
        #         echo "Ignoring $file"
        #         continue
        #     fi
        # fi

        #Ignorar ficheiros que verificam o regexpr
        if [[ "$REGEX" -eq 0 ]]; then
            if [[ "$file" =~ $EXPRESSION ]]; then
                echo "Ignoring (regex) $file"
                continue
            fi
        fi
         
        
        if [[ -f $file ]]; then
            file_backup="${file//$WORK_DIR/$BACKUP_DIR}"
                
            if [[ -e $file_backup ]]; then
                if [[ -f $file_backup ]]; then # Ficheiro que existe no backup
                    date_backup=$(date -r "$file_backup" +%s)
                    date_file=$(date -r "$file" +%s)

                    # Fazer o backup só se o ficheiro no backup é mais antigo
                    if [[ date_backup -lt date_file ]]; then 
                        #if [[ "$IGNORE" -eq 1 && $IGNORE_FILE ]] then
                        #    echo a
                        #fi
                        echo "cp -a $file $file_backup"
                        [[ "$CHECK" -eq 1 ]] && { cp -a $file $file_backup ;}
                        
                    fi
                fi
            else # Ficheiro não existente no backup
                echo "cp -a $file $file_backup"
                [[ "$CHECK" -eq 1 ]] && { cp -a $file $file_backup ;}
            fi
        else
            #É uma diretoria
            args_rec=("$@")
            args_rec[-2]="$file"
            args_rec[-1]="$BACKUP_DIR/$file"
            echo "${args_rec[@]}"
            ./backup.sh "${args_rec[@]}" 
        fi
    done
    
    for file in "$BACKUP_DIR"/*; do
        file_work="${file//$BACKUP_DIR/$WORK_DIR}"
        
        if [[ ! -e $file_work ]]; then # Apagar ficheiro do backup se não existir no dir original
            echo "rm $file"
            [[ "$CHECK" -eq 1 ]] && { rm $file ;}
        fi
    done
}


main "$@"
