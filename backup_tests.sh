#!/bin/bash

TEST_WORK_DIR="test_work"
TEST_BACKUP_DIR="test_backup"
TEST_IGNORE_FILE="ignore_file.txt"
RESULTS_FILE="test_results.txt"
REGEX="file4.txt"
TOTAL_TESTS=0
SUCCESS_TETS=0
FAILURE_TESTS=0

function generateRandomText() {
    local output_file="$1"
    for i in {1..2}; do
        head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 20
        echo
    done > "$output_file"
}

function checkResult() {
    if [[ "$1" -eq 0 ]]; then
        echo "Test result: SUCCESS"
        ((SUCCESS_TETS++))
    else 
        echo "Test result: FAILURE"
        ((FAILURE_TESTS++))
    fi
}

function addHiddenFiles() {
    generateRandomText "$TEST_WORK_DIR/subdir2/.hiddenFile.txt"
    generateRandomText "$TEST_WORK_DIR/subdir2/subdir2a/.hiddenFile.txt"
}

function addFilesWithSpaces() {
    touch "$TEST_WORK_DIR/file 5.txt"
    touch "$TEST_WORK_DIR/subdir1/file spa ces"
    mkdir "$TEST_WORK_DIR/dir with spaces"
}

function setupWorkDir() {

    rm -rf "$TEST_WORK_DIR"
    mkdir -p "$TEST_WORK_DIR/subdir1" "$TEST_WORK_DIR/subdir2" "$TEST_WORK_DIR/subdir2/subdir2a"
    # criar ficheiros no diretório de trabalho
    generateRandomText "$TEST_WORK_DIR/file1.txt"
    generateRandomText "$TEST_WORK_DIR/file2.txt"
    generateRandomText "$TEST_WORK_DIR/file3.txt"
    generateRandomText "$TEST_WORK_DIR/file4.txt"
    # criar ficheiros dentro do subdiretório 1
    generateRandomText "$TEST_WORK_DIR/subdir1/file1_subdir1.txt"
    generateRandomText "$TEST_WORK_DIR/subdir1/file2_subdir1.txt"
    generateRandomText "$TEST_WORK_DIR/subdir1/file3_subdir1.txt"
    generateRandomText "$TEST_WORK_DIR/subdir1/file4.txt"
    # criar ficheiros dentro do subdiretório 2
    generateRandomText "$TEST_WORK_DIR/subdir2/file1_subdir2.txt"
    generateRandomText "$TEST_WORK_DIR/subdir2/file2_subdir2.txt"
    # criar ficheiros dentro do subdiretório do diretório 2 
    generateRandomText "$TEST_WORK_DIR/subdir2/subdir2a/file1_subdir2a.txt"
    echo "Work directory created."
}

function setupEmptyWorkDir() {

    rm -rf "$TEST_WORK_DIR"
    mkdir -p "$TEST_WORK_DIR"
    mkdir "$TEST_WORK_DIR/subdir1"
    mkdir "$TEST_WORK_DIR/subdir2"
    mkdir "$TEST_WORK_DIR/subdir2/anotherDir"
    mkdir "$TEST_WORK_DIR/subdir2/anotherDir/anotherDir2"

}

function setupIgnoreFiles() {
    # os ficheiro ignorados sao todos os file2
    rm -f "$TEST_IGNORE_FILE" && touch "$TEST_IGNORE_FILE"
    if [[ -e "$TEST_IGNORE_FILE" ]]; then
        echo "File $TEST_IGNORE_FILE created."
    else
        echo "Error: file $TEST_IGNORE_FILE not created."
    fi
    echo
    echo "$TEST_WORK_DIR/file2.txt" >> "$TEST_IGNORE_FILE"
    echo "$TEST_WORK_DIR/subdir1/file2_subdir1.txt" >> "$TEST_IGNORE_FILE"
    echo "$TEST_WORK_DIR/subdir2/file2_subdir2.txt" >> "$TEST_IGNORE_FILE"
    echo "Files to ingnore: "
    cat "$TEST_IGNORE_FILE"
    echo
}

function testIgnoreFiles() {
    echo "=== Testing ignored files (-b [tfile]) ==="
    setupWorkDir
    ((TOTAL_TESTS++))
    echo
    local result=0
    setupIgnoreFiles
    ./backup_summary.sh -b "$TEST_IGNORE_FILE" "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" > "$RESULTS_FILE"
    echo "./backup_summary.sh -b "$TEST_IGNORE_FILE" "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" was executed."

    while IFS= read -r ignored_file; do
        if grep -q "Ignoring $ignored_file" "$RESULTS_FILE"; then
            echo "The file $ignored_file was ignored correctly."
        else
            echo "Error: The file $ignored_file was included in the backup but should be ignored."
            result=1
        fi
    done < "$TEST_IGNORE_FILE"
    echo
    checkResult "$result"
    clean
    echo
}

function clean() {
    rm -f "$TEST_IGNORE_FILE"
    rm -f "$RESULTS_FILE"
    rm -rf "$TEST_WORK_DIR"
    rm -rf "$TEST_BACKUP_DIR"
}

function modifyWorkDir() {
    rm "$TEST_WORK_DIR/file3.txt"
    rm "$TEST_WORK_DIR/subdir1/file3_subdir1.txt"
}

function createBackup() {
    mkdir -p "$TEST_BACKUP_DIR"
    ./backup_summary.sh "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" > "$RESULTS_FILE"
}

function removeBackup() {
    if [[ -d  "$TEST_BACKUP_DIR" ]]; then
        rm -rf "$TEST_BACKUP_DIR"
    fi
}

function testChecking() {
    echo "=== Testing checking option (-c) ==="
    setupWorkDir
    ((TOTAL_TESTS++))
    echo
    local result=0
    
    removeBackup
    echo "> Testing with no existing backup directory..."
    ./backup_summary.sh -c "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" > "$RESULTS_FILE"
    echo "./backup_summary.sh -c "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" was executed."

    # o diretório de backup tem de continuar a não existir
    if [[ ! -d "$TEST_BACKUP_DIR"  ]]; then
        echo "Backup directory was not created during the check."
    else
        echo "Error: Backup directory was created during the check."
        result=1
    fi

    echo
    echo "> Testing with an existing backup directory..."
    # criar o diretório de backup
    createBackup
    echo "Backup directory created."
    # modificar o diretório de trabalho
    echo "Modifying $TEST_WORK_DIR..."
    modifyWorkDir
    cp -r "$TEST_BACKUP_DIR" "$TEST_BACKUP_DIR"_before # diretorio temporário
    ./backup_summary.sh -c "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" > "$RESULTS_FILE"
    echo "./backup_summary.sh -c "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" was executed."

    if diff -r "$TEST_BACKUP_DIR" "$TEST_BACKUP_DIR"_before > "$RESULTS_FILE"; then
        echo "Backup directory was not modified during the check."
    else
        echo "Error: Backup directory was modified during the check."
        result=1
    fi

    rm -rf "$TEST_BACKUP_DIR"_before
    echo
    checkResult "$result"
    clean
    echo
}

function testRegex() {  
    echo "=== Testing regex option (-r [regexpr]) ==="
    setupWorkDir
    ((TOTAL_TESTS++))
    echo
    local result=0
    ./backup_summary.sh -r "$REGEX" "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" > "$RESULTS_FILE"
    echo "./backup_summary.sh -r "$REGEX" "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" was executed."
    local dirs=("$TEST_BACKUP_DIR" "$TEST_BACKUP_DIR/subdir1" "$TEST_BACKUP_DIR/subdir2" "$TEST_BACKUP_DIR/subdir2/subdir2a")
    
    for dir in "${dirs[@]}"; do
        for file in "$dir"/*; do
            if [[ -f "$file" ]]; then
                if [[ ! "${file##*/}" =~ $REGEX ]]; then
                    echo "Error: File $file does not match the regex."
                    result=1
                fi
            fi
        done
    done
    echo
    if [[ "$result" -eq 0 ]]; then
        echo "All files in $TEST_BACKUP_DIR check the regex expression: $REGEX"
        echo "Test result: SUCCESS"
        ((SUCCESS_TETS++))
    else 
        echo "Test result: FAILURE"
        ((FAILURE_TESTS++))
    fi
    clean
    echo
}

function backupDirInsideWorkDir() {
    echo "=== Testing backup_dir inside work_dir ==="
    echo
    setupWorkDir
    ((TOTAL_TESTS++))
    local result=0
    
    # criar diiretório backup dentro do trabalho
    mkdir -p "$TEST_WORK_DIR/$TEST_BACKUP_DIR"
    ./backup_summary.sh -c "$TEST_WORK_DIR" "$TEST_WORK_DIR/$TEST_BACKUP_DIR" > "$RESULTS_FILE"
    echo "./backup_summary.sh -c "$TEST_WORK_DIR" "$TEST_WORK_DIR/$TEST_BACKUP_DIR" was executed."

    str="Directory $TEST_WORK_DIR/$TEST_BACKUP_DIR is a subdirectory of $TEST_WORK_DIR!"
    if grep -q "$str" "$RESULTS_FILE"; then
        echo "$str"
        echo "The backup was not performed."
    else
        echo "Error: The backup was not performed."
        result=1
    fi
    echo
    checkResult "$result"
    clean
    echo
}


function test2Options() {
    echo "=== Testing 2 options ( -b [tfile] -r [regexpr]) ==="
    echo
    setupWorkDir
    setupIgnoreFiles
    ((TOTAL_TESTS++))
    local result=0

    ./backup_summary.sh -b "$TEST_IGNORE_FILE" -r "$REGEX" "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" > "$RESULTS_FILE"
    echo "./backup_summary.sh -b "$TEST_IGNORE_FILE" -r "$REGEX" "$TEST_WORK_DIR" "$TEST_BACKUP_DIR"  was executed."

    while IFS= read -r ignored_file; do
        if grep -q "Ignoring $ignored_file" "$RESULTS_FILE"; then
            echo "The file $ignored_file was ignored correctly."
        else
            echo "Error: The file $ignored_file was included in the backup but should be ignored."
            result=1
        fi
    done < "$TEST_IGNORE_FILE"

    local dirs=("$TEST_BACKUP_DIR" "$TEST_BACKUP_DIR/subdir1" "$TEST_BACKUP_DIR/subdir2" "$TEST_BACKUP_DIR/subdir2/subdir2a")
    for dir in "${dirs[@]}"; do
        for file in "$dir"/*; do
            if [[ -f "$file" ]]; then
                if [[ ! "${file##*/}" =~ $REGEX ]]; then
                    echo "Error: File $file does not match the regex."
                    result=1
                else
                    echo "File $file does match the regex. File was copied."
                fi
            fi
        done
    done
    echo
    checkResult "$result"
    echo
    clean
}

function testHiddenFiles() {
    echo "=== Testing hidden files ==="
    echo
    setupWorkDir
    ((TOTAL_TESTS++))
    local result=0
    addHiddenFiles

    ./backup_summary.sh "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" > "$RESULTS_FILE"
    echo "./backup_summary.sh "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" was executed."

    if ! ls -a "$TEST_BACKUP_DIR/subdir2" | grep -q ".hiddenFile.txt"; then
        echo "Error: .hiddenFile.txt was not copied correctly."
        result=1
    else
        echo ".hiddenFile.txt was copied correctly."
    fi

    if ! ls -a "$TEST_BACKUP_DIR/subdir2/subdir2a" | grep -q ".hiddenFile.txt"; then
        echo "Error: .hiddenFile.txt was not copied correctly."
        result=1
    else
        echo ".hiddenFile2.txt was copied correctly."
    fi
    echo
    checkResult "$result"   
    echo
    clean

}

function testFilesWithSpaces() {
    echo "=== Testing files with spaces ==="
    echo
    setupWorkDir
    ((TOTAL_TESTS++))
    local result=0
    addFilesWithSpaces

    ./backup_summary.sh "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" > "$RESULTS_FILE"
    echo "./backup_summary.sh "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" was executed."

    if [[ -e "$TEST_BACKUP_DIR/file 5.txt" ]]; then
        echo "File with spaces was copied correctly."
    else
        echo "Error: file with spaces was not copied correctly"
        result=1
    fi
    if [[ -e "$TEST_BACKUP_DIR/subdir1/file spa ces" ]]; then
        echo "File with spaces was copied correctly."
    else
        echo "Error: file with spaces was not copied correctly."
        result=1
    fi
    if [[ -d "$TEST_BACKUP_DIR/dir with spaces" ]]; then
        echo "Directory with spaces was copied correctly."
    else
        echo "Error: Directory with spaces was not copied correctly."
        result=1
    fi
    echo
    checkResult "$result"
    echo
    clean
}


function testEmptyDirectories() {
    echo "=== Testing empty directories ==="
    echo
    ((TOTAL_TESTS++))
    local result=0

    # primeiro teste com o diretório de trabalho vazio   
    rm -rf "$TEST_WORK_DIR"
    mkdir -p "$TEST_WORK_DIR"
    echo "> Testing with directory $TEST_WORK_DIR empty..."
    ./backup_summary.sh "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" > "$RESULTS_FILE"
    echo "./backup_summary.sh "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" was executed."
    if [[ -d "$TEST_BACKUP_DIR" && -z "$(ls -A $TEST_BACKUP_DIR)" ]]; then
        echo "The directory $TEST_BACKUP_DIR is empty."
    else
        echo "Error: The directory $TEST_BACKUP_DIR is not empty."
        result=1
    fi
    clean

    # segundo teste com o diretório de trabalho com subdiretórios vazios
    setupEmptyWorkDir
    echo "> Testing with directory $TEST_WORK_DIR with empty subdirectories..."
    ./backup_summary.sh "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" > "$RESULTS_FILE"
    echo "./backup_summary.sh "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" was executed."

    local dirs=( "$TEST_BACKUP_DIR/subdir1" "$TEST_BACKUP_DIR/subdir2" "$TEST_BACKUP_DIR/subdir2/anotherDir" "$TEST_BACKUP_DIR/subdir2/anotherDir/anotherDir2")
    for dir in "${dirs[@]}"; do
        
        if [[ -d "$dir" ]]; then
            if [[ -z "$(ls -A "$dir")" ]]; then
                echo "The directory $dir is completely empty."
            elif [[ -z "$(find "$dir" -maxdepth 1 -type f)" ]]; then
                echo "The directory $dir contains only subdirectories."
            else
                echo "Error: The directory $dir contains files."
                result=1
            fi
        else
            echo "Error: The directory $dir does not exist."
            result=1
        fi
    done
    echo
    checkResult "$result"
    echo
    clean
}

function testChangeBackupFile() {
    echo "=== Testing file changes in backup ==="
    echo
    ((TOTAL_TESTS++))
    local result=0
    setupWorkDir
    ./backup_summary.sh "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" > "$RESULTS_FILE"
    echo "./backup_summary.sh "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" was executed."

    # alterar conteúdo de um ficheiro no backup
    echo "Modifying content of file $TEST_BACKUP_DIR/subdir1/file4.txt..."
    sleep 1
    echo "Modifying content of file $TEST_BACKUP_DIR/subdir2/subdir2a/file1_subdir2a.txt..."
    touch "$TEST_BACKUP_DIR/subdir1/file4.txt"
    touch "$TEST_BACKUP_DIR/subdir2/subdir2a/file1_subdir2a.txt"
    sleep 1

    ./backup_summary.sh "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" > "$RESULTS_FILE"
    echo "./backup_summary.sh "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" was executed."
    if grep -Fq "WARNING: backup entry test_backup/subdir1/file4.txt is newer than test_work/subdir1/file4.txt\; Should not happen" "$RESULTS_FILE"; then
        echo "Warning found."
    else
        echo "Warning not found."
        result=1
    fi
    if grep -Fq "WARNING: backup entry test_backup/subdir2/subdir2a/file1_subdir2a.txt is newer than test_work/subdir2/subdir2a/file1_subdir2a.txt\; Should not happen" "$RESULTS_FILE"; then
        echo "Warning found."
    else
        echo "Warning not found."
        result=1
    fi
    echo
    checkResult "$result"
    echo
    clean   
}

function summaryOfTests() {
    echo
    echo "---- SUMMARY OF TESTS PERFORMED ----"
    echo
    echo "NUMBER OF TESTS PERFORMED: $TOTAL_TESTS"
    echo "NUMBER OF SUCCESSFUL TESTS: $SUCCESS_TETS"
    echo "NUMBER OF FAILED TESTS: $FAILURE_TESTS"
    echo
}


function main() {
    
    testIgnoreFiles # TESTE FICHEIROS IGNORADOS
    testChecking # TESTE OPÇÃO CHECKING
    testRegex # TESTE OPÇÃO REGEX
    backupDirInsideWorkDir # TESTE BACKUP_DIR DENTRO WORK_DIR
    test2Options # TESTE COM 2 OPÇÕES
    testHiddenFiles # TESTE FICHEIROS ESCONDIDOS
    testFilesWithSpaces # TESTE FICHEIROS COM ESPAÇOS
    testEmptyDirectories # TESTE DIRETORIAS VAZIAS
    testChangeBackupFile # TESTE ALTERAÇÃO FICHEIRO NO BACKUP

    summaryOfTests
}

main 