/*
        This script:
        - Depends on: https://raw.githubusercontent.com/triskellesolutions/azure-ubuntu-sftp/master
          - This script provides the install script, create user script, mount user sftp drives script,
            and sshd_confg file.
            - create user script, mount user sftp drives script are copied to /usr/local/bin
              - these scripts are used to add sftp users and mount their drives in /home/<user>/<downloads|uploads>
            - sshd_confg is copied over to /etc/ssh/sshd_config
            - logs are written to /vmsetup/install.log

        - Creates a virtual network

        - Creates a Azure Storage account and file service

        - Creates a network security group name
         - opens ports 22 and 9090

        - Creates a public ip addresses with a defined subdomain
          - example <dns-prefix-name>.eastus.cloudapp.azure.com

        - Creates a virtualNetworkName

        - Creates a networkInterfaces

        - Creates a VM instance of Ubuntu:

        - Executes a install script on the VM to setup and configure:
              - SFTP and SSH
              - Azure cli
              - Cockpit
              - copies scripts from gists
************************************************************************************
        - Verfiy installation:
            Access cockpit on port 9090 and use the terminal OR
            SSH INTO THE MACHINE
            REVIEW THE INSTALL LOG sudo cat /vmsetup/install.log
            - make sure the entry COMPLETED install-sftp-server.sh INSTALL EXECUTION"
************************************************************************************

        - Add users to the sftp server by executing:
           sudo /usr/local/bin/create-sftp-user.sh <username>:<password>

        - Fix mount drive issues by executing:
           sudo /usr/local/bin/mount-user-sftp-path.sh <username>

  ##############################################################################
  # Usage
  ##############################################################################

  # log into the right azure env where you have owner or contrib rights on
  # a subscription.  This should open a web browser to auth you.
  az cloud set --name AzureUSGovernment #| --name "AzureCloud"
  az login
  $subscriptionId="<subscription-id>"
  az account set --subscription "${subscriptionId}"

  # create the NEW resource group that will hold the vm instance
  $location="USGovArizona"
  $group = az group create `
    --name "<resource-group>" `
    --location "${location}" `
    --subscription "${subscriptionId}" `
    | ConvertFrom-Json
  echo $group
  $resourceGroupLocation=$group.location
  $resourceGroupName=$group.name
  $resourceGroupId=$group.id


  # create the service account with contrib on the new resource group
  $rbac = az ad sp create-for-rbac `
    --name $resourceGroupName `
    --role contributor `
    --scopes $resourceGroupId | ConvertFrom-Json

    # capture output of the command to use in the bicep script
  echo $rbac

  ###############################################################################
  #	{
  #	  "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  #	  "displayName": "display-name",
  #	  "name": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  #	  "password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx,
  #	  "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  #	}
  ################################################################################

  $serviceAccountId=$rbac.appId
  $serviceAccountPassword=$rbac.password
  $serviceAccountTenant=$rbac.tenant

  # Test the new service account and make sure you can login

  az login --service-principal -u $serviceAccountId -p $serviceAccountPassword --tenant $serviceAccountTenant

  #cd to bicep script

 az deployment group create `
  --resource-group $resourceGroupName `
  --template-file "azuredeploy.bicep" `
  --parameters  `
    resourcePrefix='<prefix-that-will-be-used-on-all-related-resources-this-script-creates-this-does-not-include-the-dns>' `
    storageAccountName='<resourcePrefix-plus-this-value-must-be-unique-in-azure>' `
    storageAccountFileShareName='<name-of-url-segment-path-of-storage>' `
    dnsNameForPublicIP='<dns-prefix-unique-in-azure-in-the-location-the-resouce-is>' `
    ubuntuOSVersion='18.04-LTS' `
    vmSize='<vm-size-make-a-good-choice-in-dev-prd>' `
    location=$resourceGroupLocation `
    resourceGroupName=$resourceGroupName `
    authenticationType='password' `
    adminUsername='<root-level-user-name-used-to-access-the-machine>' `
    adminPasswordOrKey='<strong-password>' `
    serviceAccountId=$serviceAccountId `
    serviceAccountPassword=$serviceAccountPassword `
    serviceAccountTenant=$serviceAccountTenant `
    azureCloudEnv='AzureUSGovernment'


###### ATTENTION ###################### ATTENTION ###################### ATTENTION ########
#
# Note if the error comes from the vmName_install_sfpt resource and not bicep you
# may want to remove or delete the resources from the group and rerun the above when fixed.
#
# SSH INTO THE MACHINE AND REVIEW THE INSTALL LOG sudo cat /vmsetup/install.log
#
############################################################################################
*/

@description('The resource group prefix.  This will be used as a prefix on all resources in this group.')
param resourcePrefix string = 'tss'

@description('Unique DNS Name for the Storage Account where the Virtual Machine\'s disks will be placed. This will have the resourcePrefix prepended')
param storageAccountName string = 'storage'

@description('Unique Bucket Name for the Storage Account where the Virtual Machine\'s disks will be placed.')
param storageAccountFileShareName string = 'fileshare'

@description('Unique DNS prefix for the Public IP used to access the Virtual Machine. alphanumeric ')
param dnsNameForPublicIP string

@allowed([
  '18.04-LTS'
  '16.04.0-LTS'
  '14.04.5-LTS'
])
@description('The Ubuntu version for the VM. This will pick a fully patched image of this given Ubuntu version. Allowed values: 18.04-LTS, 16.04.0-LTS, 14.04.5-LTS.')
param ubuntuOSVersion string = '18.04-LTS'

@description('Size of the virtual machine')
param vmSize string = 'Standard_B2s'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('The resource group name.')
param resourceGroupName string = resourceGroup().name

@description('Admin user name for the Virtual Machine.')
param adminUsername string

@allowed([
  'sshPublicKey'
  'password'
])
@description('Type of authentication to use on the Virtual Machine. SSH key is recommended.')
param authenticationType string = 'password'

@description('''SSH Key or password for the Virtual Machine. SSH key is recommended.
if authenticationType='password':
    The supplied password must be between 6-72 characters long and must satisfy at least 3 of password complexity requirements from the following:
    1) Contains an uppercase character
    2) Contains a lowercase character
    3) Contains a numeric digit
    4) Contains a special character
    5) Control characters are not allowed
'''')
@secure()
param adminPasswordOrKey string

@description('The service account used to connect to azure storage.')
@secure()
param serviceAccountId string
@description('The service account password used to connect to azure storage.')
@secure()
param serviceAccountPassword string
@description('The service account tenant used to connect to azure storage.')
@secure()
param serviceAccountTenant string

@description('This is the path to the version of gist we are using. Example: https://raw.githubusercontent.com/triskellesolutions/azure-ubuntu-sftp/master/<file-name>')
param gistUrlPath string = 'https://raw.githubusercontent.com/triskellesolutions/azure-ubuntu-sftp/master'

@allowed([
  'AzureCloud'
  'AzureUSGovernment'
])
@description('This is the azure cloud env we are working against.')
param azureCloudEnv string

var imagePublisher = 'Canonical'
var imageOffer = 'UbuntuServer'
var nicName_var = '${resourcePrefix}-vm-nic'
var addressPrefix = '10.0.0.0/16'
var subnetName = '${resourcePrefix}-subnet'
var subnetPrefix = '10.0.0.0/24'
var publicIPAddressName_var = '${resourcePrefix}-public-ip'
var publicIPAddressType = 'Dynamic'
var vmName_var = '${resourcePrefix}-ubuntu-vm'
var virtualNetworkName_var = '${resourcePrefix}-vnet'
var subnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName_var, subnetName)
var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}
var networkSecurityGroupName_var = '${resourcePrefix}-nsg'
var fileShareAccessTier = 'Cool'
var fullStorageAccountName=replace('${resourcePrefix}${storageAccountName}', '-', '')

resource stg 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: fullStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}
resource storageAccountName_default_fileShareName 'Microsoft.Storage/storageAccounts/fileServices/shares@2019-06-01' = {
  name: '${fullStorageAccountName}/default/${storageAccountFileShareName}'
  properties: {
    accessTier: fileShareAccessTier
  }
  dependsOn: [
    stg
  ]
}

resource publicIPAddressName 'Microsoft.Network/publicIPAddresses@2020-05-01' = {
  name: publicIPAddressName_var
  location: location
  properties: {
    publicIPAllocationMethod: publicIPAddressType
    dnsSettings: {
      domainNameLabel: dnsNameForPublicIP
    }
  }
}

resource networkSecurityGroupName 'Microsoft.Network/networkSecurityGroups@2020-05-01' =  {
  name: networkSecurityGroupName_var
  location: location
  properties: {
    securityRules: [
      {
        name: 'default-allow-22'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '22'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'default-allow-9090'
        properties: {
          priority: 1002
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '9090'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource virtualNetworkName 'Microsoft.Network/virtualNetworks@2020-05-01' =  {
  name: virtualNetworkName_var
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: {
            id: networkSecurityGroupName.id
          }
        }
      }
    ]
  }
}

resource nicName 'Microsoft.Network/networkInterfaces@2020-05-01' =  {
  name: nicName_var
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddressName.id
          }
          subnet: {
            id: subnetRef
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetworkName
  ]
}

resource vmName 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: vmName_var
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName_var
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: ((authenticationType == 'password') ? json('null') : linuxConfiguration)
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: ubuntuOSVersion
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicName.id
        }
      ]
    }
  }
  dependsOn: [
    storageAccountName_default_fileShareName
  ]
}

resource vmName_install_sfpt 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = {
  parent: vmName
  name: 'install_sftp'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      skipDos2Unix: false
      fileUris: [
        '${gistUrlPath}/install-sftp-server.sh'
      ]
    }
    protectedSettings: {
      commandToExecute: ' sudo mkdir -p /vmsetup && sudo touch /vmsetup/install.log && sh install-sftp-server.sh "${resourceGroupName}" "${fullStorageAccountName}" "${storageAccountFileShareName}" "${serviceAccountId}" "${serviceAccountPassword}" "${serviceAccountTenant}" "${gistUrlPath}" "${azureCloudEnv}" 2>&1 | sudo tee /vmsetup/install.log && sudo chmod 600 /vmsetup/install.log'
    }
  }
}

