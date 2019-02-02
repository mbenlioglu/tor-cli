#!/usr/bin/env bash

# includes
DIR="$(dirname $(readlink -f $0))"
. $DIR/bin/common.sh 

# Kill existing taskWait if requested
if [ "$1" = "--kill-taskwaiter" ]; then
    kill $(cat $TOR_CLI_HOME/taskwait.pid)
    rm "$TOR_CLI_HOME/taskwait.pid"
    exit 0
fi

# Check if packages are installed
# TODO: MOVE TO THE INSTALLER
if !([ -f $GDRIVE ] && dpkg-query -W pigz deluged deluge-console gnupg &>/dev/null); then
    echo -e "${BROWN}Missing packages detected! They will now be installed. Script might request elevation${NC}"
    mkdir -p "$BIN_DIR" "$DWN_DIR" "$KEY_DIR"
    $DIR/bin/install_prereqs.sh remote || exit 1
fi

# Change user if requested
if [ "$1" = "--change-user" ]; then
    change_user $2
fi

# Check drive for folders
check_drive


# Create and put public key for server to drive
echo -e "${BROWN}Checking server key...${NC}"
if ! gpg --list-secret-keys "Alfred Pennyworth" &>/dev/null; then
    echo -e "${BROWN}Server key doesn't exist. Creating...${NC}"
    name="Alfred Pennyworth"
	email="alfred.pennyworth@wayneenterprises.com"
	pass="theButtler#1"
	eval "cat > .buttler <<EOF
$(<$DIR/gpg_gen_template.txt)
EOF"
    gpg --batch --gen-key .buttler
	shred -ufn 5 .buttler
	update_drive=true
fi
# Export buttler's public key if not exported yet
gpg --export alfred.pennyworth@wayneenterprises.com > $KEY_DIR/alfred.pennyworth.pub

# Upload buttler's key if not uploaded yet
BUTTLER_KEY=$(safe_list -q "'$KEYS_FOLDER' in parents and name = 'alfred.pennyworth.pub'" --no-header --name-width 0 | cut -d" " -f1 -)
if [ "$BUTTLER_KEY" = "" ]; then
	echo -e "${BROWN}Uploading server's public key to drive...${NC}"
    BUTTLER_KEY=$(safe_upload "$KEY_DIR/alfred.pennyworth.pub" $KEYS_FOLDER)
elif [ "$update_drive" = true ]; then # TODO: SEND REVOCATION OF KEY TO DRIVE
    echo -e "${BROWN}Updating server's public key in drive...${NC}"
    safe_update $BUTTLER_KEY $KEY_DIR/alfred.pennyworth.pub &> /dev/null
fi

# Wait task file from drive
if [ -f "$TOR_CLI_HOME/taskwait.pid" ]; then
    echo "Already waiting for tasks on the background!. Execute $0 --kill-taskwaiter if you want to kill background process."
else
    nohup $BIN_DIR/taskWait.sh > "$TOR_CLI_HOME/taskwait.out" 2>&1 &
    echo $! > "$TOR_CLI_HOME/taskwait.pid"
fi

echo -e "${GREEN}Configuration done. Waiting for tasks...${NC}"
