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
USER_CONF="$HOME/$TOR_CLI_HOME/user.conf"

# Distro check
if [ "$(expr substr $(uname -s) 1 5)" != "Linux" ]; then
    echo -e "${RED}This script currently works on Linux only. Exiting${NC}"
    exit 1
fi

# Kill existing dataTracker if requested
if [ "$1" = "--kill-tracker" ]; then
    kill $(cat $HOME/$TOR_CLI_HOME/tracker.pid)
    exit 0
fi

# Check if packages are installed
if !([ -f $GDRIVE ] && dpkg-query -W gnupg &>/dev/null); then
    echo -e "${BROWN}Missing packages detected! They will now be installed. Script might request elevation${NC}"
    mkdir -p "$BIN_DIR" "$DWN_DIR" "$KEY_DIR"
	./install_prereqs.sh local
fi

# Change user if requested
if [ "$1" = "--reset-user" ]; then
    rm -rf ~/.gdrive
fi

# Request drive access token if doesn't exist
if [ ! -d ~/.gdrive ]; then
    $GDRIVE about
fi

# Check if drive folders for tor-cli exists, create if necessary
echo -e "${BROWN}Checking drive folders...${NC}"
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

# Check if encryption key exists create if not
if [ -f $USER_CONF ]; then
    source $USER_CONF
fi
echo -e "${BROWN}Checking your key...${NC}"
if ! gpg --list-secret-keys "$email" &>/dev/null; then
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
    echo -e "name=$name\nemail=$email" > $USER_CONF
	eval "cat > .userkey <<EOF
$(<gpg_gen_template.txt)
EOF"
    gpg --batch --gen-key .userkey
	shred -ufn 5 .userkey
	update_drive=true
fi
if [ -z "$down_path" ]; then
    uname -v | grep Microsoft &> /dev/null
    # Get default "Downloads" folder path
    if [ $? -eq 0 ]; then
        down_path=$(wslpath $(reg.exe query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"\
                    /v {374DE290-123F-4565-9164-39C4925E467B} | grep {374DE290-123F-4565-9164-39C4925E467B} | rev |\
                    cut -d" " -f1 | rev | sed 's/\r$//'))
    else
        down_path=~/Downloads
    fi
    read -ei "$down_path" -p "Enter Data download path: " down_path
    echo "down_path=$down_path" >> $USER_CONF
    if [ ! -d "$down_path" ]; then
        mkdir -p $down_path
    fi
fi

# Export users's public key if not exported yet
PUBKEY_FILE=$email.pub
if [ ! -f "$KEY_DIR/$PUBKEY_FILE" ]; then
    gpg --export $email > "$KEY_DIR/$PUBKEY_FILE"
fi

# Check drive for key upload if not exists
PUBKEY_DRIVE=$($GDRIVE list -q "'$KEYS_FOLDER' in parents and name = '$PUBKEY_FILE'" --no-header --name-width 0 | cut -d" " -f1 -)
if [ -z "$PUBKEY_DRIVE" ]; then
	echo -e "${BROWN}Uploading your public key to drive...${NC}"
    PUBKEY_DRIVE=$($GDRIVE upload "$KEY_DIR/$PUBKEY_FILE" -p $KEYS_FOLDER | cut -d$'\n' -f2 - | cut -d" " -f2 -)
elif [ "$update_drive" = true ]; then
    echo -e "${BROWN}Updating your public key in drive...${NC}"
    $GDRIVE update "$PUBKEY_DRIVE" "$KEY_DIR/$PUBKEY_FILE" &> /dev/null
fi

# Get remote buttler's public key
BUTTLER_KEY=$($GDRIVE list -q "'$KEYS_FOLDER' in parents and name = 'alfred.pennyworth.pub'" --no-header --name-width 0 | cut -d" " -f1 -)
if [ -z "$BUTTLER_KEY" ]; then
    echo "Uh oh. Your buttler hasn't put his public key to drive. Are you sure he's online?"
    exit 1
else
    $GDRIVE download --stdout "$BUTTLER_KEY" | gpg --import - &> /dev/null
fi

# Ask for torrent link
read -p "Please enter the link of torrent file or magnet link: " link

# Create task file, encrypt and upload
echo "$link" | gpg -eu "$email" -r "alfred.pennyworth@wayneenterprises.com" --trust-model always - > "$email.task"
$GDRIVE upload -p "$TASKS_FOLDER" --delete "$email.task"

# Wait for torrent to upload drive (track progress, wait for file id)
nohup $BIN_DIR/dataTrack.sh "$email" "$pass" "$down_path" &> /dev/null &
echo $! > "$HOME/$TOR_CLI_HOME/tracker.pid"

echo -e "${BROWN}Your request has been sent. A process is waiting on the background to download your file when ready."
echo -e "You can track the progress with 'tail -f $TOR_CLI_HOME/tracker.out' command."
echo -e "${GREEN}Done.${NC}"
