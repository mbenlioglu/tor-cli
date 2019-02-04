#!/usr/bin/env bash

# includes
DIR="$(dirname $(readlink -f $0))"
. $DIR/common.sh 

torrentID=$1
torrentName=$2
torrentPath=$3

RECIPIENT=$(echo "$torrentPath" | rev | cut -d"/" -f1 - | rev) # this must change with task naming convention

# Check drive for folders
check_drive

# Test if recipient key exists
if ! gpg --list-keys "$RECIPIENT" &> /dev/null; then
    if [ -f "$KEY_DIR/$RECIPIENT.pub" ]; then
        gpg --import "$KEY_DIR/$RECIPIENT.pub" &> /dev/null
    else
        while true; do
            REC_KEY=$(safe_list -q "\"'$KEYS_FOLDER' in parents and name = '$RECIPIENT.pub'\"" --no-header --name-width 0 | cut -d" " -f1 -)
            if [ -z "REC_KEY" ]; then
                sleep 60
            else
                safe_download $REC_KEY > "$KEY_DIR/$RECIPIENT.pub"
                gpg --import "$KEY_DIR/$RECIPIENT.pub" &> /dev/null
                break
            fi
        done
    fi
fi

# Track progress and put it to drive async
PROGRESS=$(safe_list -q "\"'$FILES_FOLDER' in parents and name = '$RECIPIENT.progress.gpg'\"" --no-header --name-width 0 | cut -d" " -f1 - | cut -d$'\n' -f1 -)
while true; do
    sleep 10
    deluge-console info $torrentID > "$torrentPath/$RECIPIENT.progress"
    gpg -eu "alfred.pennyworth@wayneenterprises.com" -r "$RECIPIENT" --trust-model always "$torrentPath/$RECIPIENT.progress"
    if [ -z "$PROGRESS" ]; then
        PROGRESS=$(safe_upload "$torrentPath/$RECIPIENT.progress.gpg" $FILES_FOLDER)
    elif grep "State: Downloading" "$torrentPath/$RECIPIENT.progress" &>/dev/null; then
        safe_update "$PROGRESS" "$torrentPath/$RECIPIENT.progress.gpg" &>/dev/null
    else
        break
    fi
    rm -f "$torrentPath/$RECIPIENT.progress.gpg"
done
