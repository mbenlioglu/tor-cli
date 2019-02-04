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

tar -I"pigz" -cf - "$torrentPath/$torrentName" |  gpg -z 0 -eu "alfred.pennyworth@wayneenterprises.com" -r "$RECIPIENT"\
    --trust-model always --output "$torrentPath/$RECIPIENT.tgz.gpg"
safe_upload "$torrentPath/$RECIPIENT.tgz.gpg" $FILES_FOLDER &>/dev/null

# Remove data
deluge-console rm $torrentID
rm -rf "$torrentPath"
