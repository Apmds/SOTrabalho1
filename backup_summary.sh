#!/bin/bash

function throwError() {
    ((ERRORS++))
    case "$1" in
        1)
            echo "Usage: [-c] [-b tfile] [-r regexpr] dir_trabalho dir_backup"
        ;;

        2)
            echo "Work directory $WORK_DIR does not exist!"
        ;;
        
        3)
            echo "$2 is not a file!"
        ;;

        4)
            echo "Directory $2 is a subdirectory of $3!"
        ;;
        
        *)
            echo "Something went wrong!"
        ;;
    esac

    exit $1
}

function check_errors() {
    if [[ ! $? ]]; then
        ((ERRORS++))
        case "$1" in
            1)
                echo "ERROR: Couldn't create $2 directory!"
            ;;

            2)
                echo "ERROR: Couldn't remove $2 file!"
            ;;

            3)
                echo "ERROR: Couldn't remove $2 directory!"
            ;;

            4)
                echo "ERROR: Couldn't make $2 directory!"
            ;;

            5)
                echo "ERROR: Error copying $2!"
            ;;

            *)
                echo "ERROR: Unknown error."
            ;;
        esac
    fi
}

function startupChecks() {    
    if [[ $# -lt 2 ]]; then
        throwError 1
    fi
    
    local args=("$@")
    CHECK=1
    IGNORE=1
    REGEX=1

    if [[ $# -ne 2 ]]; then
         for ((i=0; i < $#; i++)); do
            # Opção -c
            if [[ ${args[$i]} == "-c" && "$CHECK" -eq 1 ]]; then
                CHECK=0
                continue
            fi
            
            # Opção -b
            if [[ ${args[$i]} == "-b" && "$IGNORE" -eq 1 ]]; then
                IGNORE=0

                # Se o valor a seguir ao -b for um dos últimos, então há erro na sintaxe
                if [[ $(($i+1)) > $(($#-3)) ]]; then
                    throwError 1
                fi

                # Se o argumento for um ficheiro então passa um á frente
                if [[ -f ${args[$(($i+1))]} ]]; then
                    IGNORE_FILE=${args[$(($i+1))]}
                    ((i++))
                    continue
                else
                    throwError 3 ${args[$(($i+1))]}     # Ficheiro inválido
                fi
            fi

            # Opção -r
            if [[ ${args[$i]} == "-r" && "$REGEX" -eq 1 ]]; then
                REGEX=0
                
                # Se o valor a seguir ao -r for um dos últimos, então há erro na sintaxe
                if [[ $(($i+1)) > $(($#-3)) ]]; then
                    throwError 1
                fi

                # Obter a expressão regular e passar um á frente
                EXPRESSION=${args[$(($i+1))]}
                ((i++))
                continue
            fi
        done
    fi

    # Obter nomes dos diretórios
    WORK_DIR="${args[(($#-2))]%/*}"
    BACKUP_DIR="${args[(($#-1))]%/*}"
    
    # Obter nomes dos ficheiros ignorados
    if [[ $IGNORE -eq 0 ]]; then
        declare -g -A IGNORED_FILES
        while IFS= read -r line; do            
            IGNORED_FILES["$line"]=0
        done < <(grep "" $IGNORE_FILE)
    fi

    # Verificar se os diretórios não estão um dentro do outro
    aux="${BACKUP_DIR#$WORK_DIR}" # Diretório de backup sem o de trabalho
    if [[ "$aux" != "$BACKUP_DIR" ]]; then
        throwError 4 $BACKUP_DIR $WORK_DIR
    fi
    
    aux="${WORK_DIR#$BACKUP_DIR}" # Diretório de trabalho sem o de backup
    if [[ "$aux" != "$WORK_DIR" ]]; then
        throwError 4 $WORK_DIR $BACKUP_DIR
    fi

    # Verificação dos diretórios
    [[ -d "$WORK_DIR" ]] || { throwError 2; }
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "mkdir -p $BACKUP_DIR"
        [[ "$CHECK" -eq 1 ]] && { mkdir -p "$BACKUP_DIR" ; check_errors 1 "$BACKUP_DIR"; }
    fi
}

# Informação para cada diretório
function summary() {
    echo -e "While backuping "$1": $ERRORS Errors; $WARNINGS Warnings; $UPDATED Updated; $COPIED Copied ("$SIZE_COPIED"B); $DELETED Deleted ("$SIZE_DELETED"B)\n"
}

# Remove um ficheiro
function remove_file() {
    ((DELETED++))
    SIZE_DELETED=$((SIZE_DELETED + $(wc -c < "$1")))
    echo "rm $1"
    [[ "$CHECK" -eq 1 ]] && { rm "$1" ; check_errors 2 "$1"; }
}

function delete_dir() {
    local file

    local dir=$1
    local dir_work=$1

    dir_work="${dir_work%/*}"
    dir_work="${dir_work//$backupdir/$workdir}"
    dir_work="$dir_work/${dir##*/}"
    
    for file in "$dir"/*; do
        #Ignorar ficheiros
        if [[ "$IGNORE" -eq 0 ]]; then
            if [[ "${IGNORED_FILES[$file]}" ]]; then #${file#*/}]
                remove_file "$file"
                continue
            fi
        fi

        # Diretório de backup vazio
        if [ "$file" = "$dir"'/*' ]; then
            break
        fi

        # Substituir o diretório de trabalho pelo diretório de backup
        file_work="${file%/*}"
        file_work="${file_work//$backupdir/$workdir}"
        file_work="$file_work/${file##*/}"

        if [[ ! -e $file_work ]]; then # Apagar ficheiro do backup se não existir no dir original

            if [[ -d "$file" ]]; then
                delete_dir "$file"
                echo "rmdir $file"
                [[ "$CHECK" -eq 1 ]] && { rmdir "$file" ; check_errors 3 "$file"; }
            fi

            if [[ -f "$file" ]]; then
                remove_file "$file"
            fi
        fi
    done

    if [ "$dir" != "$backupdir" ]; then
        summary "$dir_work"
    else
        summary "$workdir"
    fi
}

function backup() {
    ERRORS=0
    WARNINGS=0
    UPDATED=0
    COPIED=0
    SIZE_COPIED=0
    DELETED=0
    SIZE_DELETED=0

    for file in "$1"/*; do
        #Ignorar ficheiros
        if [[ "$IGNORE" -eq 0 ]]; then
            if [[ "${IGNORED_FILES[$file]}" ]]; then #${file#*/}]
                echo "Ignoring $file."
                continue
            fi
        fi

        #Ignorar ficheiros que NÃO verificam o regexpr
        if [[ "$REGEX" -eq 0 ]]; then
            if [[ ! -d "$file" ]]; then
                if [[ ! "$file" =~ $EXPRESSION ]]; then
                    echo "Ignoring (regex) $file."
                    continue
                fi
            fi
        fi
        
        # O diretório de trabalho está vazio
        if [ "$file" = "$1"'/*' ]; then

            # Substituir o diretório de trabalho pelo diretório de backup
            dir_backup="${file%/*}"
            dir_backup="${dir_backup//$1/$2}"

            if [[ ! -d "$dir_backup" ]]; then
                echo mkdir -p "$dir_backup"
                [[ "$CHECK" -eq 1 ]] && { mkdir -p "$dir_backup"; check_errors 4 "$dir_backup"; }
            fi
            break
        fi

        if [[ ! -d $file ]]; then

            # Substituir o diretório de trabalho pelo diretório de backup
            file_backup="${file%/*}" # Diretório
            file_backup="${file_backup//$1/$2}" # Diretório substituido pelo de backup
            file_backup="$file_backup/${file##*/}" # Diretório de backup + ficheiro

            if [[ -e $file_backup ]]; then
                date_backup=$(date -r "$file_backup" +%s)
                date_file=$(date -r "$file" +%s)
                # Fazer o backup só se o ficheiro no backup é mais antigo
                if [[ "$date_backup" -lt "$date_file" ]]; then
                    echo "cp -a "$file" "$file_backup""
                    ((UPDATED++)) # ficheiro do backup atualizado
                    
                    [[ "$CHECK" -eq 1 ]] && { cp -a "$file" "$file_backup" ; check_errors 5 "$file"; }
                fi
                if [[ "$date_backup" -gt "$date_file" ]]; then
                    ((WARNINGS++))
                    echo "WARNING: backup entry "$file_backup" is newer than "$file"\; Should not happen"
                fi
            else # Ficheiro não existente no backup
                echo "cp -a $file $file_backup"
                ((COPIED++))
                SIZE_COPIED=$((SIZE_COPIED + $(wc -c < "$file")))
                [[ "$CHECK" -eq 1 ]] && { cp -a "$file" "$file_backup" ; check_errors 5 "$file"; }
            fi

        else
            #É uma diretoria
            args_rec=("$@")
            args_rec[-2]="$file"
            args_rec[-1]="$2/${file#$1/}"
            
            # Substituir o diretório de trabalho pelo diretório de backup
            file_backup="${file%/*}" # Diretório
            file_backup="${file_backup//$1/$2}" # Diretório substituido pelo de backup
            file_backup="$file_backup/${file##*/}" # Diretório de backup + ficheiro

            # Criar diretório no backup se não existe
            if [[ ! -e "$file_backup" ]]; then
                echo mkdir -p "$file_backup"
                [[ "$CHECK" -eq 1 ]] && { mkdir -p "$file_backup" ; check_errors 4 "$file_backup"; }
            fi
            
            # Salvar valores de sumário
            local local_ERRORS=$ERRORS
            local local_WARNINGS=$WARNINGS
            local local_UPDATED=$UPDATED
            local local_COPIED=$COPIED
            local local_SIZE_COPIED=$SIZE_COPIED
            local local_DELETED=$DELETED
            local local_SIZE_DELETED=$SIZE_DELETED

            backup "${args_rec[@]}"

            # Restaurar valores de sumário
            ERRORS=$local_ERRORS
            WARNINGS=$local_WARNINGS
            UPDATED=$local_UPDATED
            COPIED=$local_COPIED
            SIZE_COPIED=$local_SIZE_COPIED
            DELETED=$local_DELETED
            SIZE_DELETED=$local_SIZE_DELETED
        fi
    done

    delete_dir "$2"
}


# Criar um array com os nomes dos ficheiros do dir_backup e no loop ir apagando os ficheiros do array que existirem no dir_trabalho. Depois apagar os ficheiros do array que restarem.
function main() {
    shopt -s dotglob # Ver ficheiros escondidos

    startupChecks "$@"

    local workdir="$WORK_DIR"
    local backupdir="$BACKUP_DIR"

    backup "$workdir" "$backupdir"

    shopt -u dotglob # Parar de poder ver ficheiros escondidos
}


main "$@"
