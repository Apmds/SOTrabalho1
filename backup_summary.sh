#!/bin/bash
# Quem fez o quê?
# Explicar os testes que fizeram e porquê
# EXplicar a solução e a estrutura do código
# Bibliografia

# Os nomes dos ficheiros no -b podem ser só nomes, para ignorar todos os ficheiros com esse nome ou podem ter o caminho, para ignorar apenas esse ficheiro.
# UPDATED=0
# COPIED=0
# SIZE=0
# DELITED=0

TOTAL_ERRORS=0
TOTAL_WARNINGS=0
TOTAL_UPDATED=0
TOTAL_COPIED=0
TOTAL_SIZE_COPIED=0
TOTAL_DELETED=0
TOTAL_SIZE_DELETED=0

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
            echo "Não sei o que aconteceu! Tu sabes?"
        ;;
    esac

    exit $1
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
            #echo "${args[$i]}"
            if [[ ${args[$i]} == "-c" && "$CHECK" -eq 1 ]]; then
                CHECK=0
                continue
            fi
            if [[ ${args[$i]} == "-b" && "$IGNORE" -eq 1 ]]; then
                IGNORE=0
                if [[ $(($i+1)) > $(($#-3)) ]]; then
                    throwError 1
                fi
                if [[ -f ${args[$(($i+1))]} ]]; then
                    IGNORE_FILE=${args[$(($i+1))]}
                    ((i++))
                    continue
                else
                    throwError 3 ${args[$(($i+1))]}     # Ficheiro inválido
                fi
            fi
            if [[ ${args[$i]} == "-r" && "$REGEX" -eq 1 ]]; then
                REGEX=0
                
                if [[ $(($i+1)) > $(($#-3)) ]]; then
                    throwError 1
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
    

    # Verificar se os diretórios não estão um dentro do outro
    aux="${BACKUP_DIR#$WORK_DIR}" # Diretório substituido por o de backup
    if [[ "$aux" != "$BACKUP_DIR" ]]; then
        throwError 4 $BACKUP_DIR $WORK_DIR
    fi
    
    aux="${WORK_DIR#$BACKUP_DIR}" # Diretório substituido por o de backup
    if [[ "$aux" != "$WORK_DIR" ]]; then
        throwError 4 $WORK_DIR $BACKUP_DIR
    fi

    # Verificação dos diretórios
    [[ -d "$WORK_DIR" ]] || { throwError 2; }
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "mkdir -p $BACKUP_DIR"
        [[ "$CHECK" -eq 1 ]] && { mkdir -p "$BACKUP_DIR" ;}
    fi
}

# informação para cada diretório
function summary() {
    echo -e "While backuping "$1": $ERRORS Errors; $WARNINGS Warnings; $UPDATED Updated; $COPIED Copied ("$SIZE_COPIED"B); $DELETED Deleted ("$SIZE_DELETED"B)\n"
}

function bigSummary() {
    echo "While backuping "$1": $TOTAL_ERRORS Errors; $TOTAL_WARNINGS Warnings; $TOTAL_UPDATED Updated; $TOTAL_COPIED Copied ($TOTAL_SIZE_COPIED B); $TOTAL_DELETED Deleted ($TOTAL_SIZE_DELETED B)"
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
        #Se eles tiverem no backup têm de ser apagados??
        #if [[ "$IGNORE" -eq 0 ]]; then
        #    if [[ "${IGNORED_FILES[${file##*/}]}" ]]; then
        #        echo "Ignoring $file."
        #        continue
        #    fi
        #fi

        # Diretório de backup vazio
        if [ "$file" = "$dir"'/*' ]; then
            break
        fi

        #if [[ -d "$file" ]]; then
        #    delete_dir "$file"
        #fi

        # Substituir o diretório de trabalho pelo diretório de backup
        file_work="${file%/*}"
        file_work="${file_work//$backupdir/$workdir}"
        file_work="$file_work/${file##*/}"

        if [[ ! -e $file_work ]]; then # Apagar ficheiro do backup se não existir no dir original

            if [[ -d "$file" ]]; then
                delete_dir "$file"
                echo "rmdir $file"
                [[ "$CHECK" -eq 1 ]] && { rmdir "$file" ;}
            fi

            if [[ -f "$file" ]]; then
                ((DELETED++))
                SIZE_DELETED=$((SIZE_DELETED + $(wc -c < "$file")))
                echo "rm $file"
                [[ "$CHECK" -eq 1 ]] && { rm "$file" ;}
            fi
        fi
    done

    updateTotalVariables

    if [ "$dir" != "$backupdir" ]; then
        summary "$dir_work"
    else
        summary "$workdir"
    fi
}

function updateTotalVariables() {
    TOTAL_ERRORS=$((TOTAL_ERRORS + $ERRORS))
    TOTAL_WARNINGS=$((TOTAL_WARNINGS + $WARNINGS))
    TOTAL_UPDATED=$((TOTAL_UPDATED + $UPDATED))
    TOTAL_COPIED=$((TOTAL_COPIED + $COPIED))
    TOTAL_SIZE_COPIED=$((TOTAL_SIZE_COPIED + $SIZE_COPIED))
    TOTAL_DELETED=$((TOTAL_DELETED + $DELETED))
    TOTAL_SIZE_DELETED=$((TOTAL_SIZE_DELETED + $SIZE_DELETED))
}

function backup() {

    ERRORS=0
    WARNINGS=0
    UPDATED=0
    COPIED=0
    SIZE_COPIED=0
    DELETED=0
    SIZE_DELETED=0

    #num_files=$(ls -1q "$WORK_DIR" | wc -l)
    #
    #if [[ "$num_files" -eq 0 ]]; then
    #    return
    #fi

    for file in "$1"/*; do
        #echo "dir1 $1"
        #echo "dir2 $2"
        #Ignorar ficheiros
        #Se eles tiverem no backup têm de ser apagados??
        if [[ "$IGNORE" -eq 0 ]]; then
            if [[ "${IGNORED_FILES[$file]}" ]]; then #${file##*/}]
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

            #echo DIR TRABALHO: "$1"
            #echo DIR BACKUP: "$2"

            # Substituir o diretório de trabalho pelo diretório de backup
            dir_backup="${file%/*}"
            dir_backup="${dir_backup//$1/$2}"

            if [[ ! -d "$dir_backup" ]]; then
                echo mkdir -p "$dir_backup"
                [[ "$CHECK" -eq 1 ]] && { mkdir -p "$dir_backup"; }
            fi
            break
        fi

        if [[ ! -d $file ]]; then

            # Substituir o diretório de trabalho pelo diretório de backup
            file_backup="${file%/*}" # Diretório
            file_backup="${file_backup//$1/$2}" # Diretório substituido pelo de backup
            file_backup="$file_backup/${file##*/}" # Diretório de backup + ficheiro

            if [[ -e $file_backup ]]; then
                if [[ -f $file_backup ]]; then # Ficheiro que existe no backup
                    date_backup=$(date -r "$file_backup" +%s)
                    date_file=$(date -r "$file" +%s)

                    # Fazer o backup só se o ficheiro no backup é mais antigo
                    if [[ "$date_backup" -lt "$date_file" ]]; then 
                        #if [[ "$IGNORE" -eq 1 && $IGNORE_FILE ]] then
                        #    echo a
                        #fi

                        ## COLORCAR TEXTO DE CRIAR DIRETÓRIO

                        echo "cp -a "$file" "$file_backup""

                        ((UPDATED++)) # ficheiro do backup atualizado
                        #((COPIED++))
                        #SIZE_COPIED=$((SIZE_COPIED + $(wc -c < "$file")))
                        
                        [[ "$CHECK" -eq 1 ]] && { cp -a "$file" "$file_backup" ;}
                    fi

                    if [[ "$date_backup" -gt "$date_file" ]]; then
                        ((WARNINGS++))
                        echo "WARNING: backup entry "$file_backup" is newer than "$file"\; Should not happen"
                    fi

                fi
            else # Ficheiro não existente no backup
                echo "cp -a $file $file_backup"
                ((COPIED++))
                SIZE_COPIED=$((SIZE_COPIED + $(wc -c < "$file")))
                [[ "$CHECK" -eq 1 ]] && { cp -a "$file" "$file_backup" ;}
            fi

        else
            #summary "$1"
            #É uma diretoria
            args_rec=("$@")
            args_rec[-2]="$file"
            args_rec[-1]="$2/${file#$1/}"
            #echo "${args_rec[@]}"
            
            # Substituir o diretório de trabalho pelo diretório de backup
            file_backup="${file%/*}" # Diretório
            file_backup="${file_backup//$1/$2}" # Diretório substituido pelo de backup
            file_backup="$file_backup/${file##*/}" # Diretório de backup + ficheiro

            # Criar diretório no backup se não existe
            if [[ ! -e "$file_backup" ]]; then
                echo mkdir -p "$file_backup"
                [[ "$CHECK" -eq 1 ]] && { mkdir -p "$file_backup" ;}
            fi
            
            # Salvar valores
            local local_ERRORS=$ERRORS
            local local_WARNINGS=$WARNINGS
            local local_UPDATED=$UPDATED
            local local_COPIED=$COPIED
            local local_SIZE_COPIED=$SIZE_COPIED
            local local_DELETED=$DELETED
            local local_SIZE_DELETED=$SIZE_DELETED

            backup "${args_rec[@]}"

            # Restaurar valores
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
    #echo "Ignored files: ${IGNORED_FILES[@]}"
    #echo "$EXPRESSION"

    local workdir="$WORK_DIR"
    local backupdir="$BACKUP_DIR"

    backup "$workdir" "$backupdir"
    #updateTotalVariables
    #summary "${args_rec[0]}"

    #delete_dir "$backupdir"

    #bigSummary "$workdir"
    shopt -u dotglob # Parar de poder ver ficheiros escondidos
}


main "$@"
