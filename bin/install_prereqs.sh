#!/usr/bin/env bash
# if [ $EUID != 0 ]; then
    # sudo "$0" "$@"
    # exit $?
# fi

# includes
DIR="$(dirname $(readlink -f $0))"
. $DIR/common.sh

#TODO: Needed dynamic detection for package managers etc.

# Not used now, not deleted as it may be needed for later updates
get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

# Distro check
if [ "$(cat /etc/*release | grep UBUNTU_CODENAME | cut -d= -f2)" != "bionic" ]; then
    echo -e "${RED}This script currently works on Ubuntu bionic only. Stay tuned for updates. Exiting${NC}"
    exit 1
fi

# Create home dir, move files
mkdir -p $BIN_DIR $KEY_DIR $DWN_DIR
# HACK: mv command doesn't work as expected in WSL. Small hack to overcome it
uname -v | grep Microsoft &>/dev/null && cp -rfa ./* $TOR_CLI_HOME/ && rm -rf ./*\
    || mv -f ./* $TOR_CLI_HOME/

echo -e "${GREEN}Fetching prerequired packages${NC}"
echo -e "${BROWN}"
# Download gdrive
echo 'Installing gdrive' # TODO: links need update
if [ $(uname -m) = "i386" ]; then
    dwnlink="https://docs.google.com/uc?id=0B3X9GlR6EmbnLV92dHBpTkFhTEU&export=download"
elif [ $(uname -m) = "x86_64" ]; then
    dwnlink="https://docs.google.com/uc?id=0B3X9GlR6EmbnQ0FtZmJJUXEyRTA&export=download"
fi
curl -L $dwnlink -o $GDRIVE --progress-bar

#Install deluge, gnupg, pigz
if [ "$1" = "remote" ]; then
    echo y | sudo apt-get install pigz deluged deluge-console gnupg
    deluged && sleep 1; deluge-console plugin -e Execute && sleep 1
    deluge-console exit && deluge-console halt; sleep 1
    echo "{
  \"file\": 1, 
  \"format\": 1
}{
  \"commands\": [
    [
      \"0\", 
      \"added\", 
      \"$BIN_DIR/onTorrentAdded.sh\"
    ], 
    [
      \"1\", 
      \"complete\", 
      \"$BIN_DIR/onTorrentComplete.sh\"
    ]
  ]
}" > ~/.config/deluge/execute.conf
    deluged
    ln -s $TOR_CLI_HOME/remote.sh ./remote.sh
elif [ "$1" = "local" ]; then
    echo y | sudo apt-get install gnupg pigz
    ln -s $TOR_CLI_HOME/local.sh ./local.sh
else
    echo -e "${RED} wrong parameter${NC}"
	exit 1
fi

chmod u+x $BIN_DIR/*

# Ask for drive login
echo -e "${NC}"
$GDRIVE about
echo -e "${GREEN}Done.${NC}"
