#!/bin/bash
sudo dpkg --configure -a
sudo apt-get -y update

# install
sudo apt-get -y install wget openssh-server net-tools

#wget https://software.virtualmin.com/gpl/scripts/install.sh
#sudo /bin/sh install.sh



