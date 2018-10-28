#!/usr/bin/env bash

BROWN='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

TOR_CLI_HOME=".torcli"
BIN_DIR="$HOME/$TOR_CLI_HOME/bin"
DWN_DIR="$HOME/$TOR_CLI_HOME/downloads"
KEY_DIR="$HOME/$TOR_CLI_HOME/pub_keys"
GDRIVE="$BIN_DIR/gdrive"

# Check drie folders
GDRIVE_HOME=$($GDRIVE list -q "name = '$TOR_CLI_HOME'" --no-header --name-width 0 | cut -d" " -f 1 -)
if [ -z "$GDRIVE_HOME" ]; then
    GDRIVE_HOME=$($GDRIVE mkdir "$TOR_CLI_HOME" | cut -d" " -f 2 -)
fi
KEYS_FOLDER=$($GDRIVE list -q "'$GDRIVE_HOME' in parents and name = 'pub_keys'" --no-header --name-width 0 | cut -d" " -f 1 -)
if [ -z "$KEYS_FOLDER" ]; then
    KEYS_FOLDER=$($GDRIVE mkdir "pub_keys" -p $GDRIVE_HOME | cut -d" " -f 2 -)
fi
TASKS_FOLDER=$($GDRIVE list -q "'$GDRIVE_HOME' in parents and name = 'tasks'" --no-header --name-width 0 | cut -d" " -f 1 -)
if [ -z "$TASKS_FOLDER" ]; then
    TASKS_FOLDER=$($GDRIVE mkdir "tasks" -p $GDRIVE_HOME | cut -d" " -f 2 -)
fi
FILES_FOLDER=$($GDRIVE list -q "'$GDRIVE_HOME' in parents and name = 'files'" --no-header --name-width 0 | cut -d" " -f 1 -)
if [ -z "$FILES_FOLDER" ]; then
    FILES_FOLDER=$($GDRIVE mkdir "files" -p $GDRIVE_HOME | cut -d" " -f 2 -)
fi

# Wait task file from drive (check every minute)
while true; do
    TASKS=$($GDRIVE list -q "'$TASKS_FOLDER' in parents and name contains 'task'" --no-header --name-width 0)
    TASK_ID=$(echo $TASKS | cut -d" " -f1 - | cut -d$'\n' -f1 -)
    TASK_NAME=$(echo $TASKS | cut -d" " -f4 - | cut -d$'\n' -f1 - | rev | cut -d. -f2- - | rev)
    if [ -z "$TASKS" ]; then
        sleep 60
    else
        mkdir -p "$DWN_DIR/$TASK_NAME"
        # Dowload torrent file
        deluge-console add $($GDRIVE download --stdout $TASK_ID | gpg --batch --quiet --passphrase "theButtler#1" -d -) -p "$DWN_DIR/$TASK_NAME"
    fi
done

