/*
        This script will:
        - Depends on gist: https://gist.github.com/johnbabb/e385e10ea9dd06ddc3ea3160e7403dab
          - This script provides the install script, create user script, mount user sftp drives script,
            and sshd_confg file.
            - create user script, mount user sftp drives script are copied to /usr/local/bin
              - these scripts are used to add sftp users and mount their drives in /home/<user>/<downloads|uploads>
            - sshd_confg is copied over to /etc/ssh/sshd_config

        - Creates a virtual network

        - Creates a Azure Storage account and file service

        - Creates a network security group name
         - opens ports 22 and 9090

        - Creates a public ip addresses with a defined subdomain
          - example <dns-prefix-name>.eastus.cloudapp.azure.com

        - Creates a virtualNetworkName

        - Creates a networkInterfaces

        - Creates a VM instance of Ubuntu:

        - Executes a custom script on the VM
              - SFTP and SSH
              - Azure cli
              - Cockpit
              - copies scripts from gists

  ##############################################################################
  # Usage
  ##############################################################################

  # log into the right azure env where you have owner or contrib rights on
  # a subscription.  This should open a web browser to auth you.

  az login

  # create the rsouece group that will hold the vm instance

  az group create --name "<resource-group>" --location "<location>" --subscription "<subscription-id>"

  # create the service account
  az ad sp create-for-rbac `
    --name "<resource-group>" `
    --role contributor `
    --scopes /subscriptions/<subscription-id>/resourceGroups/<resource-group>

  # capture output of the command to use in the bicep script

  ###############################################################################
  #	{
  #	  "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  #	  "displayName": "display-name",
  #	  "name": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  #	  "password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx,
  #	  "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  #	}
  ################################################################################

  az deployment group create `
  --resource-group <resource-group> `
  --template-file "<path to script>ubuntu-vm.bicep" `
  --parameters  `
    resourcePrefix='<prefix-that-will-be-used-on-all-related-resources-this-script-creates>' `
    storageAccountName='storage' `
    storageAccountFileShareName='sis' `
    dnsNameForPublicIP='<dns-prefix-name>' `
    ubuntuOSVersion='<version>' `
    vmSize='vm-size' `
    location=<location>`
    resourceGroupName=<resouce-group-name>`
    authenticationType='password' `
    adminUsername='<root-level-user-name-used-to-access-the-machine>' `
    adminPasswordOrKey='<strong-password>' `
    serviceAccountId='xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' `
    serviceAccountPassword='xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' `
    serviceAccountTenant='xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' `

*/
@description('The resource group prefix.  This will be used as a prefix on all resources in this group.')
param resourcePrefix string = 'tss'

@description('Unique DNS Name for the Storage Account where the Virtual Machine\'s disks will be placed.')
param storageAccountName string = 'storage'

@description('Unique Bucket Name for the Storage Account where the Virtual Machine\'s disks will be placed.')
param storageAccountFileShareName string = 'fileshare'

@description('Admin user name for the Virtual Machine.')
param adminUsername string

@description('Unique DNS prefix for the Public IP used to access the Virtual Machine.')
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

@allowed([
  'sshPublicKey'
  'password'
])
@description('Type of authentication to use on the Virtual Machine. SSH key is recommended.')
param authenticationType string = 'password'

@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
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

@description('This is the path to the version of gist we are using. Example: https://gist.githubusercontent.com/johnbabb/e385e10ea9dd06ddc3ea3160e7403dab/raw/d76809b6c5c5f07984ea131124f9cd093b7cc4f1')
param gistUrlPath string = 'https://gist.githubusercontent.com/johnbabb/e385e10ea9dd06ddc3ea3160e7403dab/raw/d76809b6c5c5f07984ea131124f9cd093b7cc4f1'


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
      commandToExecute: ' sudo mkdir -p /vmsetup && sudo touch /vmsetup/install.log && sh install-sftp-server.sh "${resourceGroupName}" "${fullStorageAccountName}" "${storageAccountFileShareName}" "${serviceAccountId}" "${serviceAccountPassword}" "${serviceAccountTenant}" "${gistUrlPath}" 2>&1 | sudo tee /vmsetup/install.log'
    }
  }
}

output scriptLogs string = reference('${vmName_install_sfpt.id}/logs/default', vmName_install_sfpt.apiVersion, 'Full').properties.log
