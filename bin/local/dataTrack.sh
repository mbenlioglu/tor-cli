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

email=$1
dwn_path=$2

# Wait for file to be ready...

# Download file, decrypt, unpack archieve

# Remove task file
