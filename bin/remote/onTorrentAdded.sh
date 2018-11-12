#!/usr/bin/env bash
BIN_DIR="$TOR_CLI_HOME/bin"
DWN_DIR="$TOR_CLI_HOME/downloads"
KEY_DIR="$TOR_CLI_HOME/pub_keys"
GDRIVE="$BIN_DIR/gdrive"

torrentID=$1
torrentName=$2
torrentPath=$3

RECIPIENT=$(echo "$torrentPath" | rev | cut -d"/" -f1 - | rev) # this must change with task naming convention
# Get home folder id from drive
GDRIVE_HOME=$($GDRIVE list -q "name = '$(basename $TOR_CLI_HOME)'" --no-header --name-width 0 | cut -d" " -f 1 -)
if [ -z "$GDRIVE_HOME" ]; then
    GDRIVE_HOME=$($GDRIVE mkdir "$(basename $TOR_CLI_HOME)" | cut -d" " -f 2 -)
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

# Test if recipient key exists
if ! gpg --list-keys "$RECIPIENT" &> /dev/null; then
    if [ -f "$KEY_DIR/$RECIPIENT.pub" ]; then
        gpg --import "$KEY_DIR/$RECIPIENT.pub" &> /dev/null
    else
        while true; do
            REC_KEY=$($GDRIVE list -q "'$KEYS_FOLDER' in parents and name = '$RECIPIENT.pub'" --no-header --name-width 0 | cut -d" " -f1 -)
            if [ -z "REC_KEY" ]; then
                sleep 60
            else
                $GDRIVE download -f --path "$KEY_DIR" $REC_KEY &> /dev/null
                gpg --import "$KEY_DIR/$RECIPIENT.pub" &> /dev/null
                break
            fi
        done
    fi
fi

# Track progress and put it to drive async
PROGRESS=
while true; do
    if [ ! -f "$torrentPath/$RECIPIENT.progress" ]; then
        deluge-console info $torrentID > "$torrentPath/$RECIPIENT.progress"
        gpg -eu "alfred.pennyworth@wayneenterprises.com" -r "$RECIPIENT" --trust-model always "$torrentPath/$RECIPIENT.progress"
        PROGRESS=$($GDRIVE upload "$torrentPath/$RECIPIENT.progress.gpg" -p $FILES_FOLDER | cut -d$'\n' -f2 - | cut -d" " -f2 -)
        rm -f "$torrentPath/$RECIPIENT.progress.gpg"
    elif grep "State: Downloading" "$torrentPath/$RECIPIENT.progress" &> /dev/null; then
        deluge-console info $torrentID > "$torrentPath/$RECIPIENT.progress"
        gpg -eu "alfred.pennyworth@wayneenterprises.com" -r "$RECIPIENT" --trust-model always "$torrentPath/$RECIPIENT.progress"
        $GDRIVE update "$PROGRESS" "$torrentPath/$RECIPIENT.progress.gpg" &>/dev/null
        rm -f "$torrentPath/$RECIPIENT.progress.gpg"
        sleep 10
    else
        break
    fi
done
