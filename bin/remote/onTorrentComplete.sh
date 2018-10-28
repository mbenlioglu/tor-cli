#!/usr/bin/env bash
TOR_CLI_HOME=".torcli"
BIN_DIR="$HOME/$TOR_CLI_HOME/bin"
DWN_DIR="$HOME/$TOR_CLI_HOME/downloads"
KEY_DIR="$HOME/$TOR_CLI_HOME/pub_keys"
GDRIVE="$BIN_DIR/gdrive"

torrentID=$1
torrentName=$2
torrentPath=$3

# Terminate progress tracker process

# Archieve and encrypt data with public key
RECIPENT=$(echo $torrentPath | rev | cut -d"/" -f2- - | rev)
tar -I"pigz" -cf "$torrentPath/$RECIPENT.tgz" "$torrentPath/$torrentName"

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

# Test if recipient key exists
if ! gpg --list-keys "$RECIPENT" &> /dev/null; then
    if [ -f "$KEY_DIR/$RECIPENT.pub" ]; then
        gpg --import "$KEY_DIR/$RECIPENT.pub" &> /dev/null
    else
        while true; do
            REC_KEY=$($GDRIVE list -q "'$KEYS_FOLDER' in parents and name = '$RECIPENT.pub'" --no-header --name-width 0 | cut -d" " -f1 -)
            if [ -z "REC_KEY" ]; then
                sleep 60;
            else
                $GDRIVE download -f --path "$KEY_DIR" $REC_KEY &> /dev/null
                gpg --import "$KEY_DIR/$RECIPENT.pub" &> /dev/null
            fi
        done
    fi
fi

gpg -z 0 -eu "alfred.pennyworth@wayneenterprises.com" -r "$RECIPENT" --trust-model always -output - "$torrentPath/$RECIPENT.tgz" \
    | $GDRIVE upload - "$RECIPENT.tgz.gpg" -p $FILES_FOLDER &>/dev/null

# Remove data
deluge-console rm $torrentID --remove_data
rm -rf "$torrentPath"
