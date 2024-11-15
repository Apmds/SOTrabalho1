#!/bin/bash

TEST_WORK_DIR="test_work"
TEST_BACKUP_DIR="test_backup"
TEST_IGNORE_FILE="ignore_file.txt"
RESULTS_FILE="test_results.txt"

function generateRandomText() {
    local output_file="$1"
    for i in {1..5}; do
        head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 20
        echo
    done > "$output_file"
}

function setupWorkDir() {

    rm -rf "$TEST_WORK_DIR"
    mkdir -p "$TEST_WORK_DIR/subdir1" "$TEST_WORK_DIR/subdir2"

    # criar ficheiros no diretório de trabalho
    generateRandomText "$TEST_WORK_DIR/file1.txt"
    generateRandomText "$TEST_WORK_DIR/file2.txt"
    generateRandomText "$TEST_WORK_DIR/file3.txt"

    # criar ficheiros dentro do subdiretório 1
    generateRandomText "$TEST_WORK_DIR/subdir1/file1_subdir1.txt"
    generateRandomText "$TEST_WORK_DIR/subdir1/file2_subdir1.txt"
    generateRandomText "$TEST_WORK_DIR/subdir1/file3_subdir1.txt"

    # criar ficheiros dentro do subdiretório 2
    generateRandomText "$TEST_WORK_DIR/subdir2/file1_subdir2.txt"
    generateRandomText "$TEST_WORK_DIR/subdir2/file2_subdir2.txt"

    # criar subdiretorio dentro do subdiretório 2
    mkdir -p "$TEST_WORK_DIR/subdir2/subdir2a"
    generateRandomText "$TEST_WORK_DIR/subdir2/subdir2a/file1_subdir2a.txt"
}

function setupIgnoreFiles() {
    # os ficheiro ignorados sao todos os file2
    rm -f "$TEST_IGNORE_FILE" && touch "$TEST_IGNORE_FILE"
    echo "$TEST_WORK_DIR/file2.txt" >> "$TEST_IGNORE_FILE"
    echo "$TEST_WORK_DIR/subdir1/file2_subdir1.txt" >> "$TEST_IGNORE_FILE"
    echo "$TEST_WORK_DIR/subdir2/file2_subdir2.txt" >> "$TEST_IGNORE_FILE"
}

function testIgnoreFiles() {
    local result=0
    setupIgnoreFiles
    ./backup_summary.sh -b "$TEST_IGNORE_FILE" "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" > "$RESULTS_FILE"

    while IFS= read -r ignored_file; do
        if grep -q "Ignoring $ignored_file" "$RESULTS_FILE"; then
            echo "The file $ignored_file was ignored correctly."
        else
            echo "Error: The file $ignored_file was included in the backup but should be ignored."
            result=1
        fi
    done < "$TEST_IGNORE_FILE"
    #echo "Backup summary:"
    #cat "$RESULTS_FILE"
    echo
    [[ "$result" -eq 0 ]] && echo "Test result: SUCCESS" || echo "Test result: FAILURE"
}

function clean() {
    rm "$TEST_IGNORE_FILE"
    rm "$RESULTS_FILE"
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
    local result=0
    
    removeBackup
    echo "Testing with no existing backup directory..."
    ./backup_summary.sh -c "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" > "$RESULTS_FILE"

    # o diretório de backup tem de continuar a não existir
    if [[ ! -d "$TEST_BACKUP_DIR"  ]]; then
        echo "Backup directory was not created during the check."
    else
        echo "Error: Backup directory was created during the check."
        result=1
    fi

    # criar o diretório de backup
    createBackup
    # modificar o diretório de trabalho
    echo "Modifying $TEST_WORK_DIR..."
    modifyWorkDir
    echo
    echo "Testing with an existing backup directory..."
    cp -r "$TEST_BACKUP_DIR" "$TEST_BACKUP_DIR"_before # diretorio temporário
    ./backup_summary.sh -c "$TEST_WORK_DIR" "$TEST_BACKUP_DIR" > "$RESULTS_FILE"


    if diff -r "$TEST_BACKUP_DIR" "$TEST_BACKUP_DIR"_before > "$RESULTS_FILE"; then
        echo "Backup directory was not modified during the check."
    else
        echo "Error: Backup directory was modified during the check."
        result=1
    fi

    rm -rf "$TEST_BACKUP_DIR"_before
    echo
    [[ "$result" -eq 0 ]] && echo "Test result: SUCCESS" || echo "Test result: FAILURE"

}

function main() {

    # TESTE FICHEIROS IGNORADOS
    echo "=== Testing ignored files ==="
    setupWorkDir
    setupIgnoreFiles
    testIgnoreFiles
    echo

    # TESTE OPÇÃO CHECKING
    echo "=== Testing checking option ==="
    setupWorkDir # não parece que seja necessário
    testChecking 





    clean
}

main 