#!/usr/bin/env bash

touch "packages.txt" # Packages list

cat << EOF > packages.txt
git
gcc
EOF

PATHTOLIST="./packages.txt"

# Fail on error and report it, debug all lines
set -eu -o pipefail

# Check if script is run as sudo
[[ $(id -u) -eq 0 ]] || { echo >&2 "You should have sudo privilege to run this script"; exit 1; }

# Installation process
echo "Ready to install the following packages:"
echo "$(cat $PATHTOLIST)"

read -p "Do you wish to continue? " yn
case $yn in
    [Yy]* ) apt-get install $(cat $PATHTOLIST);;
    [Nn]* ) exit;;
    * ) echo "Please answer yes or no.";;
esac
