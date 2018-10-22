#!/usr/bin/env bash
if [ $EUID != 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

TOR_CLI_HOME='.torcli'
BIN_DIR='~/$TOR_CLI_HOME/bin'
GDRIVE='$BIN_DIR/gdrive'

BROWN='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Distro check
if [ "$(expr substr $(uname -s) 1 5)" != "Linux" ]; then
    echo -e "${RED}This script currently works on Linux only. Exiting${NC}"
    exit 1
fi

# Not used now, not deleted as it may be needed for later updates
get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

echo -e "${GREEN}Fetching prerequired packages${NC}"

mkdir -p $BIN_DIR
echo -e "${BROWN}"
# Download gdrive
echo 'Installing gdrive'
if [ $(uname -m) = "i386" ]; then
    dwnlink="https://docs.google.com/uc?id=0B3X9GlR6EmbnLV92dHBpTkFhTEU&export=download"
elif [ $(uname -m) = "x86_64" ]; then
    dwnlink="https://docs.google.com/uc?id=0B3X9GlR6EmbnQ0FtZmJJUXEyRTA&export=download"
fi
curl -L $dwnlink -o $GDRIVE --progress-bar
chmod +x $GDRIVE

#Install deluge, gnupg, pigz
if [ "$1" -eq "remote" ]; then
    echo y | apt-get install pigz deluged deluge-console gnupg
    echo "{
  \"file\": 1, 
  \"format\": 1
}{
  \"commands\": [
    [
      \"0\", 
      \"added\", 
      \"$(pwd)/onTorrentAdded.sh\"
    ], 
    [
      \"1\", 
      \"complete\", 
      \"$(pwd)/onTorrentComplete.sh\"
    ]
  ]
}" > ~/.config/deluge/execute.conf
    deluged && sleep 1; deluge-console plugin -e Execute
elif [ "$!" -eq "local" ]; then
    echo y | apt-get install gnupg
else
    echo -e "${RED} wrong parameter${NC}"
	exit $?
fi

echo -e "${GREEN}Done.${NC}"
