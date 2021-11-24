#!/bin/bash
dpkg --configure -a
apt-get -y update

# install
apt-get -y install wget

sudo apt-get -y install openssh-server net-tools
#. /etc/os-release
#sudo apt install -t ${VERSION_CODENAME}-backports cockpit

wget https://software.virtualmin.com/gpl/scripts/install.sh
sudo /bin/sh install.sh