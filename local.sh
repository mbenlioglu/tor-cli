#!/usr/bin/env bash

BROWN='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

TOR_CLI_HOME='.torcli'
BIN_DIR='~/$TOR_CLI_HOME/bin'
DWN_DIR='~/$TOR_CLI_HOME/downloads'
KEY_DIR='~/$TOR_CLI_HOME/pub_keys'

GDRIVE='$BIN_DIR/gdrive'
USER_CONF='~/$TOR_CLI_HOME/user.conf'

# Distro check
if [ "$(expr substr $(uname -s) 1 5)" != "Linux" ]; then
    echo -e "${RED}This script currently works on Linux only. Exiting${NC}"
    exit 1
fi

# Check if packages are installed
if !([ -f $GDRIVE ] && dpkg-query -W gnupg &>/dev/null); then
    echo -e "${BROWN}Missing packages detected! They will now be installed. Script might request elevation${NC}"
	./install_prerqs.sh local
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
GDRIVE_HOME=$($GDRIVE list -q "name contains '$TOR_CLI_HOME'" --no-header | cut -d" " -f 1 -)
if [ "$GDRIVE_HOME" = "" ]; then
    GDRIVE_HOME=$($GDRIVE mkdir "$TOR_CLI_HOME" | cut -d" " -f 2 -)
fi
KEYS_FOLDER=$($GDRIVE list -q "'$GDRIVE_HOME' in parents and name contains 'pub_keys'" --no-header | cut -d" " -f 1 -)
if [ "$KEYS_FOLDER" = "" ]; then
    KEYS_FOLDER=$($GDRIVE mkdir "pub_keys" -p $GDRIVE_HOME | cut -d" " -f 2 -)
fi
TASKS_FOLDER=$($GDRIVE list -q "'$GDRIVE_HOME' in parents and name contains 'tasks'" --no-header | cut -d" " -f 1 -)
if [ "$TASKS_FOLDER" = "" ]; then
    TASKS_FOLDER=$($GDRIVE mkdir "tasks" -p $GDRIVE_HOME | cut -d" " -f 2 -)
fi
FILES_FOLDER=$($GDRIVE list -q "'$GDRIVE_HOME' in parents and name contains 'files'" --no-header | cut -d" " -f 1 -)
if [ "$FILES_FOLDER" = "" ]; then
    FILES_FOLDER=$($GDRIVE mkdir "files" -p $GDRIVE_HOME | cut -d" " -f 2 -)
fi

# Check if encryption key exists create if not
if [ -f $USER_CONF ]; then
    source $USER_CONF
fi
echo -e "${BROWN}Checking your key...${NC}"
if ! gpg --list-secret-keys "$email" &>/dev/null; then
    echo -e "${BROWN}No secret key found in your name creating now...${NC}"
	read -p 'Full Name ($name): ' $name
	read -p 'Email ($email): ' $email
	while true; do
	    read -sp 'Password: ' $pass
	    echo
	    read -sp 'Password (again): ' $pass2
	    echo
	    [ "$pass" = "$pass2" ] && break
	    echo "Passwords don't match! Please try again"
	done
    echo -e 'name="$name"\nemail="$email"' > $USER_CONF
	eval "cat > .userkey <<EOF
$(<gpg_gen_template.txt)
EOF"
    gpg --batch --gen-key .userkey
	shred -ufn 5 .userkey
	update_drive=true
fi

# Export users's public key if not exported yet
PUBKEY_FILE=$email.asc
if [ ! -f $KEY_DIR/$PUBKEY_FILE ]; then
    gpg --export $email > $KEY_DIR/$PUBKEY_FILE
fi

# Check drive for key upload if not exists
PUBKEY_DRIVE=$($GDRIVE list -q "'$KEYS_FOLDER' in parents and name contains '$PUBKEY_FILE'" --no-header | cut -d" " -f1 -)
if [ "$PUBKEY_DRIVE" = "" ]; then
	echo -e "${BROWN}Uploading your public key to drive...${NC}"
    PUBKEY_DRIVE= $($GDRIVE upload "$KEY_DIR/$PUBKEY_FILE" -p $KEYS_FOLDER | cut -d$"\n" -f2 - | cut -d" " -f2 -)
elif [ "$update_drive" = true ]; then
    echo -e "${BROWN}Updating your public key in drive...${NC}"
    $GDRIVE update $PUBKEY_DRIVE $KEY_DIR/$PUBKEY_FILE &> /dev/null
fi

# Get remote buttler's public key
BUTTLER_KEY=$($GDRIVE list -q "'$KEYS_FOLDER' in parents and name contains 'alfred.pennyworth.asc'" --no-header | cut -d" " -f1 -)
if [ "$BUTTLER_KEY" = "" ]; then
    echo "Uh oh. Your buttler hasn't put his public key to drive. Are you sure he's online?"
    exit 1
else
    $GDRIVE download --stdout $BUTTLER_KEY | gpg --import - &> /dev/null
fi

# Ask for torrent link
read -p 'Please enter the link of torrent file or magnet link: ' $link

# Create task file, encrypt and upload
echo "$link" | gpg -eu "$email" -r "alfred.pennyworth@wayneenterprises.com" --trust-model always - > "$email.task"
$GDRIVE upload -p "$TASKS_FOLDER" --delete "$email.task"

# Wait for torrent to upload drive (track progress, wait for file id)

# Download file, decrypt, unpack archieve

# Remove task file
