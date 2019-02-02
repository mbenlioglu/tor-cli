#!/usr/bin/env bash

BROWN='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

TOR_CLI_HOME=${TOR_CLI_HOME:-"$HOME/.torcli"}
BIN_DIR="$TOR_CLI_HOME/bin"
DWN_DIR="$TOR_CLI_HOME/downloads"
KEY_DIR="$TOR_CLI_HOME/pub_keys"

GDRIVE="$BIN_DIR/gdrive"
export GDRIVE_CONFIG_DIR="$TOR_CLI_HOME/.gdrive"
GDRIVE_TOKENS_DIR="$GDRIVE_CONFIG_DIR/token_v2.d"

USER_CONF="$TOR_CLI_HOME/user.conf"


# Echo error message to stderr
errcho () {
    >&2 echo $@
}

# Random string generator of length given in $1 defaults to lenght 32
randstr () {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1-32} | head -n 1
}

# Compares two dot seperated numerical versions
# If version $1 is:
#        - equal to $2:     returns 0
#        - greater than $2: returns 1
#        - less than $2:    returns 2
vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

# Change drive user
change_user () {
    local username response
    rm -f $GDRIVE_CONFIG_DIR/token_v2.json
    if [ -z "$1" ]; then
        read -ep "Enter new email address for drive: " username
    else
        username=$1
    fi
    
    # Check tokens cache to see if user is previously authenticated
    if [ ! -f "$GDRIVE_TOKENS_DIR/$username" ]; then
        errcho -e "${RED}You haven't signed in with this user before. Please sign in ${NC}"
        exec 3>&1
        while true; do
            response=$($GDRIVE about | tee >(cat - >&3))
            if echo "$response" | grep Failed ; then
                errcho "Retrying in 5 seconds..."
                sleep 5
            else break; fi
        done
        exec 3>&-
        
        username=$(echo "$response" | grep User | rev | cut -d" " -f1 | rev)
        mv "$GDRIVE_CONFIG_DIR/token_v2.json" "$GDRIVE_TOKENS_DIR/$username"
    fi
    ln -fs "$GDRIVE_TOKENS_DIR/$username" "$GDRIVE_CONFIG_DIR/token_v2.json"
    echo "Successfully changed user to ${username}"
}

# Check if drive folders for tor-cli exists, create if necessary
check_drive () {
    echo -e "${BROWN}Checking drive folders...${NC}"
    while true; do
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
        
        # Break if none failed failed
        if [[ ${GDRIVE_HOME} != "Failed" && ${KEYS_FOLDER} != "Failed" && \
             ${TASKS_FOLDER} != "Failed" && ${FILES_FOLDER} != "Failed" ]]; then
            break
        fi
        # Try again in 5 seconds
        errcho "Failed to get folder information from the cloud. Trying again in 5 seconds"
        sleep 5
    done
}

# Upload file given in $1 to the Goodgle Drive folder given in $2
# With retry mechanism for failures and file verification with MD5 checksum
safe_upload () {
    local MD5SUM REMOTE_MD5 FILE
    if [ ! -f $1 ]; then
        errcho "Local file ($1) does not exist!"
        return 1
    fi

    MD5SUM=$(md5sum $1 | cut -d" " -f1 -)
    #Upload
    FILE=$($GDRIVE upload --no-progress $1 -p $2 | cut -d$'\n' -f2 - | cut -d" " -f2 -)
    #Verify integrity, update if necessary
    errcho "Verifying file..."
    while true; do
        REMOTE_MD5=$($GDRIVE info ${FILE} | grep Md5sum | cut -d" " -f2 -)
        if [ -z "${REMOTE_MD5}" ]; then
            errcho "File is not uploaded to cloud. Retrying in 5 seconds..."
            sleep 5
            FILE=$($GDRIVE upload --no-progress $1 -p $2 | cut -d$'\n' -f2 - | cut -d" " -f2 -)
        elif [[ ${REMOTE_MD5} == "Failed" ]]; then
            errcho "Failed to get file information from cloud. Trying again in 5 seconds"
            sleep 5
        elif [ "${REMOTE_MD5}" != "${MD5SUM}" ]; then
            errcho "Remote file integrity is corrupted. Fixing..."
            sleep 5;
            $GDRIVE update ${FILE} $1 &> /dev/null
        else
            break
        fi
    done
    echo "${FILE}"
}

# Download file with ID given in $1 to stdout
# With retry mechanism for failures and file verification with MD5 checksum
safe_download () {
    local MD5SUM REMOTE_MD5 FILE
    MD5SUM=
    while true; do
        REMOTE_MD5=$($GDRIVE info ${FILE} | grep Md5sum | cut -d" " -f2 -)
        if [ -z "${REMOTE_MD5}" ]; then
            errcho "File is not found in cloud. Retrying in 5 seconds..."
            sleep 5
        elif [[ ${REMOTE_MD5} == "Failed" ]]; then
            errcho "Failed to get file information from cloud. Trying again in 5 seconds"
            sleep 5
        else
            FILE=$(randstr)
            $GDRIVE download --stdout $1 > /tmp/${FILE}
            MD5SUM=$(md5sum "/tmp/${FILE}" | cut -d" " -f1 -)
            if [[ -z "$MD5SUM" || ${MD5SUM} != ${REMOTE_MD5} ]]; then
                errcho "File cannot be downloaded or integrity corrupted during download! Retrying in 5 seconds..."
                rm -f /tmp/${FILE}
                sleep 5
            else
                break
            fi
    done
    cat /tmp/${FILE} && rm -f tmp/${FILE}
}

# Update a file in cloud with given ID in $1 with the local file given in $2
# With retry mechanism for failures and file verification with MD5 checksum
safe_update () {
    local MD5SUM REMOTE_MD5
    if [ ! -f $2 ]; then
        errcho "Local file ($2) does not exist!"
        return 1
    fi
    
    MD5SUM=$(md5sum $1 | cut -d" " -f1 -)
    while true; do
        REMOTE_MD5=$($GDRIVE info ${FILE} | grep Md5sum | cut -d" " -f2 -)
        if [ -z "${REMOTE_MD5}" ]; then
            errcho "File is not found in cloud. Retrying in 5 seconds..."
            sleep 5
        elif [[ ${REMOTE_MD5} == "Failed" ]]; then
            errcho "Failed to get file information from cloud. Trying again in 5 seconds"
            sleep 5
        elif [[ ${MD5SUM} = ${REMOTE_MD5} ]]; then
            break
        else
            $GDRIVE update $1 $2 &> /dev/null
        fi
    done
}

# Send list request to drive with retry mechanism against failures (same parameters as original)
safe_list () {
    local RESPONSE
    while true; do
        RESPONSE=$($GDRIVE list $@)
        echo "${RESPONSE}" | grep Failed &> /dev/null && errcho "Failed to get information from cloud. Trying again in 5 seconds" \
            && sleep 5 || break
    done
    echo "$RESPONSE"
}

# Send delete request to drive with retry mechanism against failures (same parameters as original)
safe_delete () {
    local RESPONSE
    while true; do
        RESPONSE=$($GDRIVE delete $@)
        echo "${RESPONSE}" | grep Failed &> /dev/null && errcho "Failed delete from cloud. Trying again in 5 seconds" \
            && sleep 5 || break
    done
    echo "$RESPONSE"
}

