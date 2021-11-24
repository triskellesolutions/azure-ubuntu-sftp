#!/bin/bash
dpkg --configure -a
apt-get -y update

# install
apt-get -y install wget

wget https://software.virtualmin.com/gpl/scripts/install.sh
sudo /bin/sh install.sh