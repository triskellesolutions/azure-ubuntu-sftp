#!/bin/bash
sudo dpkg --configure -a
sudo apt-get -y update

# install sftp
sudo apt-get -y install wget openssh-server net-tools

# install cockpit
. /etc/os-release
sudo apt install -t ${VERSION_CODENAME}-backports cockpit
sudo systemctl --now enable cockpit.socket
sudo sudo ufw allow 9090/tcp


