#!/bin/bash
resourceGroupName=$1
storageAccountName=$2
storageAccountFileShareName=$3
serviceAccountId=$4
serviceAccountPassword=$5
serviceAccountTenant=$6
gistUrl=$7
storageAccountMountPath="/mount/$storageAccountName/$storageAccountFileShareName"

sudo mkdir -p /vmsetup && sudo touch /vmsetup/install.keys

sudo echo "resourceGroupName=$1"               >> /vmsetup/install.keys
sudo echo "storageAccountName=$2"              >> /vmsetup/install.keys
sudo echo "storageAccountFileShareName=$3"     >> /vmsetup/install.keys
sudo echo "serviceAccountId=$4"                >> /vmsetup/install.keys
sudo echo "serviceAccountPassword=$5"          >> /vmsetup/install.keys
sudo echo "serviceAccountTenant=$6"            >> /vmsetup/install.keys
sudo echo "storageAccountMountPath=$storageAccountMountPath"  >> /vmsetup/install.keys

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

sudo chmod 600 /vmsetup/install.keys

installScript() {
    fileName="$1"
    filePath="$2"
    sudo touch $filePath$fileName
    sudo chmod 777  $filePath$fileName
    sudo curl -sl "${gistUrl}/${fileName}" > $filePath$fileName
    sudo chown root:root $filePath$fileName
    sudo chmod 600  $filePath$fileName
    sudo chmod +x  $filePath$fileName
}

installScript create-sftp-user.sh '/usr/local/bin/'
installScript mount-user-sftp-path.sh '/usr/local/bin/'
installScript sshd_config '/etc/ssh/'
sudo chmod -x  '/etc/ssh/sshd_config'

sudo systemctl restart ssh

sudo groupadd sftpusers

code=0 && response=$(az login --service-principal -u $serviceAccountId -p $serviceAccountPassword --tenant $serviceAccountTenant 2>&1) || code=$?
if [ $code != 0 ]; then
    echo 'Error: could not log in with the provided service account.\nFrom this point forward you will have to execute this code below on your own.'
    echo "You will probably have to create a new secret for the account ${serviceAccountId}"
    echo $response
    exit $code
fi
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

echo "smbCredentialFile=$smbCredentialFile" | sudo tee -a /vmsetup/install.keys

sudo  mkdir -p $storageAccountMountPath
storageAccountSmbPathFileShare="$smbPath$storageAccountFileShareName"
echo "$storageAccountSmbPathFileShare $storageAccountMountPath cifs nofail,credentials=$smbCredentialFile,serverino" |  sudo tee -a /etc/fstab > /dev/null

echo "storageAccountSmbPathFileShare=$storageAccountSmbPathFileShare" | sudo tee -a /vmsetup/install.keys

sudo mount $storageAccountSmbPathFileShare

echo "COMPLETED $0 INSTALL EXECUTION"
