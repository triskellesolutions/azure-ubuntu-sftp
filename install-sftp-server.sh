#!/bin/bash
resourceGroupName=$1
storageAccountName=$2
storageAccountFileShareName=$3
serviceAccountId=$4
serviceAccountPassword=$5
serviceAccountTenant=$6

sudo mkdir -p /vmsetup && sudo touch /vmsetup/install.keys

echo "resourceGroupName=$1"              | sudo tee -a /vmsetup/install.keys
echo "storageAccountName=$2"             | sudo tee -a /vmsetup/install.keys
echo "storageAccountFileShareName=$3"    | sudo tee -a /vmsetup/install.keys
echo "serviceAccountId=$4"               | sudo tee -a /vmsetup/install.keys
echo "serviceAccountPassword=$5"         | sudo tee -a /vmsetup/install.keys
echo "serviceAccountTenant=$6"           | sudo tee -a /vmsetup/install.keys

sudo dpkg --configure -a
sudo apt-get -y update

# install sftp
sudo apt-get -y install wget openssh-server net-tools ca-certificates curl apt-transport-https lsb-release gnupg vim
sudo apt-get update
# install cockpit
. /etc/os-release
sudo apt -y install -t ${VERSION_CODENAME}-backports cockpit
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

az login --service-principal -u $serviceAccountId -p $serviceAccountPassword --tenant $serviceAccountTenant

# config mounts
httpEndpoint=$(az storage account show \
    --resource-group $resourceGroupName \
    --name $storageAccountName \
    --query "primaryEndpoints.file" --output tsv | tr -d '"')
smbPath=$(echo $httpEndpoint | cut -c7-$(expr length $httpEndpoint))
fileHost=$(echo $smbPath | tr -d "/")


nc -zvw3 $fileHost 445

# Create a folder to store the credentials for this storage account and
# any other that you might set up.
credentialRoot="/etc/smbcredentials"
sudo mkdir -p "/etc/smbcredentials"

# Get the storage account key for the indicated storage account.
# You must be logged in with az login and your user identity must have
# permissions to list the storage account keys for this command to work.
storageAccountKey=$(az storage account keys list \
    --resource-group $resourceGroupName \
    --account-name $storageAccountName \
    --query "[0].value" --output tsv | tr -d '"')

# Create the credential file for this individual storage account
smbCredentialFile="$credentialRoot/$storageAccountName.cred"
if [ ! -f $smbCredentialFile ]; then
    echo "username=$storageAccountName" |  sudo tee $smbCredentialFile > /dev/null
    echo "password=$storageAccountKey" |   sudo tee -a $smbCredentialFile > /dev/null
else
    echo "The credential file $smbCredentialFile already exists, and was not modified."
fi

# Change permissions on the credential file so only root can read or modify the password file.
sudo chmod 600 $smbCredentialFile

mntPath="/mount/$storageAccountName/$storageAccountFileShareName"
sudo  mkdir -p $mntPath

echo "$smbPath$storageAccountFileShareName $mntPath cifs nofail,credentials=$smbCredentialFile,serverino" |  sudo tee -a /etc/fstab > /dev/null

sudo mount $mntPath
