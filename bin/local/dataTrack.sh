#!/usr/bin/env bash

# includes
DIR="$(dirname $(readlink -f $0))"
. $DIR/common.sh 


email=$1
pass=$2
dwn_path=$3

# Check drive for folders
check_drive

# Wait for file to be ready...
while true; do
    FILE=$(safe_list -q "\"'$FILES_FOLDER' in parents and name = '$email.tgz.gpg'\"" --no-header --name-width 0 | cut -d" " -f1 - | cut -d$'\n' -f1 -)
    PROGRESS=$(safe_list -q "\"'$FILES_FOLDER' in parents and name = '$email.progress.gpg'\"" --no-header --name-width 0 | cut -d" " -f1 - | cut -d$'\n' -f1 -)
    if [ -z "$FILE" ]; then
        # Print download status of the torrent
        if [ -z "$PROGRESS" ]; then
            echo "No progress has been submitted by the remote server yet!!"
        else
            safe_download "$PROGRESS" | gpg --batch --quiet --pinentry-mode loopback --passphrase "$pass" -d -
        fi
        sleep 10;
    else
        # Download file, decrypt, unpack archieve
        echo "Downloading your file from drive..."
        safe_download "$FILE" | gpg --batch --quiet --pinentry-mode loopback --passphrase "$pass" -d - | tar -I"unpigz" -xf - -C "$dwn_path"
        break
    fi
done

# Remove task file
TASK_ID=$(safe_list -q "\"'$TASKS_FOLDER' in parents and name contains '$email.task'\"" --no-header --name-width 0 | cut -d" " -f1 - | cut -d$'\n' -f1 -)
if [ ! -z "$TASK_ID" ]; then
    safe_delete $TASK_ID &> /dev/null
fi
safe_delete "$PROGRESS" &> /dev/null
safe_delete "$FILE" &> /dev/null

# Remove pid entry
rm "$TOR_CLI_HOME/tracker.pid"
