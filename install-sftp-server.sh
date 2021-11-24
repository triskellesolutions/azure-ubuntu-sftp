#!/bin/bash
sudo dpkg --configure -a
sudo apt-get -y update

# install sftp
sudo apt-get -y install wget openssh-server net-tools ca-certificates curl apt-transport-https lsb-release gnupg
sudo apt-get update
# install cockpit
. /etc/os-release
sudo apt install -t ${VERSION_CODENAME}-backports cockpit
sudo systemctl --now enable cockpit.socket
sudo ufw allow 9090/tcp

# install azure cli
curl -sL https://packages.microsoft.com/keys/microsoft.asc |
    gpg --dearmor |
    sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" |
    sudo tee /etc/apt/sources.list.d/azure-cli.list
sudo apt-get update   
sudo apt-get -y install azure-cli
    
    

