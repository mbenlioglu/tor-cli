#!/usr/bin/env bash
torrentID=$1
torrentName=$2
torrentPath=$3

# Terminate progress tracker process

# Archieve and encrypt data with public key
tar -I"pigz" -cf sadfsadf.tgz $torrentPath/

# Upload to drive

# Add drive file id to progress file

# Remove torrent
deluge-console "rm $torrentID --remove_data"

# Remove task file from drive
