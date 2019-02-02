#!/usr/bin/env bash

# includes
DIR="$(dirname $(readlink -f $0))"
. $DIR/common.sh 

# Check drive for folders
check_drive

# Wait task file from drive (check every minute)
while true; do
    TASKS=$(safe_list -q "'$TASKS_FOLDER' in parents and name contains 'task'" --no-header --name-width 0)
    TASK_ID=$(echo "$TASKS" | cut -d" " -f1 - | cut -d$'\n' -f1 -)
    TASK_NAME=$(echo "$TASKS" | cut -d" " -f4 - | cut -d$'\n' -f1 - | rev | cut -d. -f2- - | rev)
    if [ -z "$TASKS" ]; then
        sleep 60
    else
        mkdir -p "$DWN_DIR/$TASK_NAME"
        # Dowload torrent file
        deluge-console add $(safe_download $TASK_ID | gpg --batch --quiet --pinentry-mode loopback --passphrase "theButtler#1" -d -) -p "$DWN_DIR/$TASK_NAME"
        safe_delete $TASK_ID &> /dev/null
    fi
done

