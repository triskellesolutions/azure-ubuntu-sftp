#!/bin/bash
sudo dpkg --configure -a
sudo apt-get -y update

# install
sudo apt-get -y install wget openssh-server net-tools
#. /etc/os-release
#sudo apt install -t ${VERSION_CODENAME}-backports cockpit

wget https://software.virtualmin.com/gpl/scripts/install.sh
sudo /bin/sh install.sh



