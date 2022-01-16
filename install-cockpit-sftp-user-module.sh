#!/bin/bash
set -Eeo pipefail

# shellcheck disable=2154
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

. /vmsetup/install.keys

sudo mkdir -p ~/.local/share/cockpit/sftp-users
sudo ln -s ~/.local/share/cockpit/sftp-users /usr/share/cockpit


