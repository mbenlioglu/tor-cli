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

# Distro check
if [ "$(expr substr $(uname -s) 1 5)" != "Linux" ]; then
    echo -e "${RED}This script currently works on Linux only. Exiting${NC}"
    exit 1
fi

# Check if packages are installed
if !([ -f $GDRIVE ] && dpkg-query -W pigz deluged deluge-console gnupg &>/dev/null); then
    echo -e "${BROWN}Missing packages detected! They will now be installed. Script might request elevation${NC}"
    ./install_prerqs.sh remote
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

# Create and put public key for server to drive
echo -e "${BROWN}Checking server key...${NC}"
if ! gpg --list-secret-keys "Alfred Pennyworth" &>/dev/null; then
    echo -e "${BROWN}Server key doesn't exist. Creating...${NC}"
    name="Alfred Pennyworth"
	email="alfred.pennyworth@wayneenterprises.com"
	pass="theButtler#1"
	eval "cat > .buttler <<EOF
$(<gpg_gen_template.txt)
EOF"
    gpg --batch --gen-key .buttler
	shred -ufn 5 .buttler
	update_drive=true
fi

# Export buttler's public key if not exported yet
if [ ! -f $KEY_DIR/alfred.pennyworth.asc ]; then
    gpg --export alfred.pennyworth@wayneenterprises.com > $KEY_DIR/alfred.pennyworth.asc
fi

# Upload buttler's key if not uploaded yet
BUTTLER_KEY=$($GDRIVE list -q "'$KEYS_FOLDER' in parents and name contains 'alfred.pennyworth.asc'" --no-header | cut -d" " -f1 -)
if [ "$BUTTLER_KEY" = "" ]; then
	echo -e "${BROWN}Uploading server's public key to drive...${NC}"
    BUTTLER_KEY= $($GDRIVE upload "$KEY_DIR/alfred.pennyworth.asc" -p $KEYS_FOLDER | cut -d$"\n" -f2 - | cut -d" " -f2 -)
elif [ "$update_drive" = true ]; then
    echo -e "${BROWN}Updating server's public key in drive...${NC}"
    $GDRIVE update $BUTTLER_KEY $KEY_DIR/alfred.pennyworth.asc &> /dev/null
fi

# Wait task file from drive (check every minute)

# Dowload torrent file
deluge-console add 

