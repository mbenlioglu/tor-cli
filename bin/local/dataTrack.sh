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

email=$1
pass=$2
dwn_path=$3

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

# Wait for file to be ready...
while true; do
    FILE=$($GDRIVE list -q "'$FILES_FOLDER' in parents and name = '$email.tgz.gpg'" --no-header --name-width 0 | cut -d" " -f1 -)
    PROGRESS=$($GDRIVE list -q "'$FILES_FOLDER' in parents and name = '$email.progress.gpg'" --no-header --name-width 0 | cut -d" " -f1 -)
    if [ -z "$FILE" ]; then
        # Print download status of the torrent
        if [ -z "PROGRESS" ]; then
            echo "No progress has been submitted by the remote server yet!!" > "$HOME/$TOR_CLI_HOME/tracker.out"
        else
            $GDRIVE download --stdout "$PROGRESS" | gpg --batch --quiet --passphrase "$pass" -d - > "$HOME/$TOR_CLI_HOME/tracker.out"
        fi
        sleep 10;
    else
        # Download file, decrypt, unpack archieve
        echo "Downloading your file from drive..." > "$HOME/$TOR_CLI_HOME/tracker.out"
        $GDRIVE download --stdout "$FILE" | gpg --batch --quiet --passphrase "$pass" -d - | tar -I"unpigz" -xf - -C "dwn_path"
        break
    fi
done

# Remove task file
TASK_ID=$($GDRIVE list -q "'$TASKS_FOLDER' in parents and name contains 'task'" --no-header --name-width 0 | cut -d" " -f1 - | cut -d$'\n' -f1 -)
if [ ! -z "$TASK_ID" ]; then
    $GDRIVE delete $TASK_ID &> /dev/null
fi
$GDRIVE delete "$PROGRESS" &> /dev/null
$GDRIVE delete "$FILE" &> /dev/null

# Remove pid entry
rm "$HOME/$TOR_CLI_HOME/tracker.pid"
