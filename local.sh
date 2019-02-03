#!/usr/bin/env bash

# includes
DIR="$(dirname $(readlink -f $0))"
. $DIR/bin/common.sh 

# Kill existing dataTracker if requested
if [ "$1" = "--kill-tracker" ]; then
    kill $(cat $TOR_CLI_HOME/tracker.pid)
    rm "$TOR_CLI_HOME/tracker.pid"
    exit 0
fi

# Check if packages are installed
# TODO: MOVE TO INSTALLER
if !([ -f $GDRIVE ] && dpkg-query -W gnupg &>/dev/null); then
    echo -e "${BROWN}Missing packages detected! They will now be installed. Script might request elevation${NC}"
	$DIR/bin/install_prereqs.sh local || exit 1
fi

# Change user if requested
if [ "$1" = "--change-user" ]; then
    change_user $2
fi

# Check drive for folders
check_drive

# Check if encryption key exists create if not
if [ -f $USER_CONF ]; then
    . $USER_CONF
fi
echo -e "${BROWN}Checking your key...${NC}"
if [ -z "$email" ]; then
    echo -e "${BROWN}No secret key found in your name. Creating now...${NC}"
	read -ei "$name" -p 'Full Name: ' name
	read -ei "$email" -p 'Email: ' email
	while true; do
	    read -sp 'Password: ' pass
	    echo
	    read -sp 'Password (again): ' pass2
	    echo
	    [ "$pass" = "$pass2" ] && break
	    echo "Passwords don't match! Please try again"
	done
    echo -e "name=\"$name\"\nemail=\"$email\"" > $USER_CONF
fi

if ! gpg --list-secret-keys "$email" &>/dev/null; then
    eval "cat > .userkey <<EOF
$(<$DIR/gpg_gen_template.txt)
EOF"
    gpg --batch --gen-key .userkey
    shred -ufn 5 .userkey
    update_drive=true
fi
# Export users's public key if not exported yet
PUBKEY_FILE=$email.pub
gpg --export $email > "$KEY_DIR/$PUBKEY_FILE"

if [ -z "$down_path" ]; then
    # Get default "Downloads" folder path (special check for bash on Windows)
    if uname -v | grep Microsoft &> /dev/null; then
        down_path=$(wslpath $(reg.exe query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"\
                    /v {374DE290-123F-4565-9164-39C4925E467B} | grep {374DE290-123F-4565-9164-39C4925E467B} | rev |\
                    cut -d" " -f1 | rev | sed 's/\r$//'))
    else
        down_path=$HOME/Downloads
    fi
    read -ei "$down_path" -p "Enter Data download path: " down_path
    echo "down_path=$down_path" >> $USER_CONF
    if [ ! -d "$down_path" ]; then
        mkdir -p $down_path
    fi
fi

# Check drive for key upload if not exists
PUBKEY_DRIVE=$(safe_list -q "'$KEYS_FOLDER' in parents and name = '$PUBKEY_FILE'" --no-header --name-width 0 | cut -d" " -f1 -)
if [ -z "$PUBKEY_DRIVE" ]; then
	echo -e "${BROWN}Uploading your public key to drive...${NC}"
    PUBKEY_DRIVE=$(safe_upload "$KEY_DIR/$PUBKEY_FILE" $KEYS_FOLDER)
elif [ "$update_drive" = true ]; then # TODO: SEND REVOCATION OF KEY TO DRIVE
    echo -e "${BROWN}Updating your public key in drive...${NC}"
    safe_update "$PUBKEY_DRIVE" "$KEY_DIR/$PUBKEY_FILE" &> /dev/null
fi

# Get remote buttler's public key
BUTTLER_KEY=$(safe_list -q "'$KEYS_FOLDER' in parents and name = 'alfred.pennyworth.pub'" --no-header --name-width 0 | cut -d" " -f1 -)
if [ -z "$BUTTLER_KEY" ]; then
    echo "Uh oh. Your buttler hasn't put his public key to drive. Are you sure he's online?"
    exit 1
else
    safe_download "$BUTTLER_KEY" | gpg --import - &> /dev/null
fi

if [ -f "$TOR_CLI_HOME/tracker.pid" ]; then
    echo "Multiple torrent requests currently not supported please wait your previous torrent to finish"
else
    # Ask for torrent link
    read -ep "Please enter the link of torrent file or magnet link: " link

    # Create task file, encrypt and upload
    echo "$link" | gpg -eu "$email" -r "alfred.pennyworth@wayneenterprises.com" --trust-model always - > "$email.task"
    safe_upload "$email.task" "$TASKS_FOLDER" &> /dev/null && rm "$email.task"

    # Wait for torrent to upload drive (track progress, wait for file id)
    nohup $BIN_DIR/dataTrack.sh "$email" "$pass" "$down_path" > /dev/null 2>&1 &
    echo $! > "$TOR_CLI_HOME/tracker.pid"
fi

echo -e "${BROWN}Your request has been sent. A process is waiting on the background to download your file when ready."
echo -e "You can track the progress with 'tail -f $TOR_CLI_HOME/tracker.out' command."
echo -e "${GREEN}Done.${NC}"
