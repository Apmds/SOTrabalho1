#!/bin/bash
#Quem fex o quê?
#Explicar oss testes que fizeram e porquê
# Eplicar a solução e a estrutura do código
# Bibliografia

function throwError() {
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
            if [[ ${args[$i]} == "-c" ]]; then
                CHECK=0
                continue
            fi
            if [[ ${args[$i]} == "-b" ]]; then
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
            if [[ ${args[$i]} == "-r" ]]; then
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
    
    # Verificação dos diretórios
    [[ -d "$WORK_DIR" ]] || { throwError 2; }
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
                echo "Ignoring $file."
                continue
            fi
        fi

        #Ignorar ficheiros que verificam o regexpr
        if [[ "$REGEX" -eq 0 ]]; then
            if [[ "$file" =~ $EXPRESSION ]]; then
                echo "Ignoring (regex) $file."
                continue
            fi
        fi
         
        
        if [[ -f $file ]]; then
            

            # Substituir o diretório de trabalho pelo diretório de backup
            file_backup="${file%/*}"
            file_backup="${file_backup//$WORK_DIR/$BACKUP_DIR}"
            file_backup="$file_backup/${file##*/}"
                
            if [[ -e $file_backup ]]; then
                if [[ -f $file_backup ]]; then # Ficheiro que existe no backup
                    date_backup=$(date -r "$file_backup" +%s)
                    date_file=$(date -r "$file" +%s)

                    # Fazer o backup só se o ficheiro no backup é mais antigo
                    if [[ date_backup -lt date_file ]]; then 
                        #if [[ "$IGNORE" -eq 1 && $IGNORE_FILE ]] then
                        #    echo a
                        #fi
                        echo "cp -a "$file" "$file_backup""
                        
                        [[ "$CHECK" -eq 1 ]] && { cp -a "$file" "$file_backup" ;}
                    fi
                fi
            else # Ficheiro não existente no backup
                echo "cp -a $file $file_backup"
                [[ "$CHECK" -eq 1 ]] && { cp -a "$file" "$file_backup" ;}
            fi
        else
            #É uma diretoria
            args_rec=("$@")
            args_rec[-2]="$file"
            args_rec[-1]="$BACKUP_DIR/${file#$WORK_DIR/}"
            #echo "${args_rec[@]}"
            ./backup.sh "${args_rec[@]}"
        fi
    done
    
    for file in "$BACKUP_DIR"/*; do
        #Ignorar ficheiros
        #Se eles tiverem no backup têm de ser apagados??
        #if [[ "$IGNORE" -eq 0 ]]; then
        #    if [[ "${IGNORED_FILES[${file##*/}]}" ]]; then
        #        echo "Ignoring $file."
        #        continue
        #    fi
        #fi

        # Substituir o diretório de trabalho pelo diretório de backup
        file_work="${file%/*}"
        file_work="${file_work//$BACKUP_DIR/$WORK_DIR}"
        file_work="$file_work/${file##*/}"
        
        if [[ ! -e $file_work ]]; then # Apagar ficheiro do backup se não existir no dir original
            echo "rm $file"
            [[ "$CHECK" -eq 1 ]] && { rm "$file" ;}
        fi
    done
}


main "$@"
