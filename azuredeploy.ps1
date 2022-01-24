
# $subscriptionId='<subscriptionIdValue>'
# $location='<locationValue>'
# $resourceGroupName='<resourceGroupNameValue>'
# $azureCloudEnv='<azureCloudEnvValue>'
# $newOrExisting='<newOrExistingValue>'
# $azureDeployBicepFile='<azureDeployBicepFileValue>'
# $storageAccountName='<storageAccountNameValue>'
# $storageAccountFileShareName='<storageAccountFileShareNameValue>'
# $storageAccountResouceGroupName='<storageAccountResouceGroupNameValue>'
# $dnsNameForPublicIP='<dnsNameForPublicIPValue>'
# $ubuntuOSVersion='<ubuntuOSVersionValue>'
# $vmSize='<vmSizeValue>'
# $authenticationType='<authenticationTypeValue>'
# $adminUsername='<adminUsernameValue>'
# $adminPasswordOrKey='<adminPasswordOrKeyValue>'

. ./.keys/azuredeploy-config.ps1

az cloud set --name $azureCloudEnv
az login

az account set --subscription "${subscriptionId}"

# create the NEW resource group that will hold the vm instance

$group = az group create `
  --name "${resourceGroupName}" `
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
  --scopes "/subscriptions/${subscriptionId}" | ConvertFrom-Json

  # capture output of the command to use in the bicep script
echo $rbac


$serviceAccountId=$rbac.appId
$serviceAccountPassword=$rbac.password
$serviceAccountTenant=$rbac.tenant

az login --service-principal -u $serviceAccountId -p $serviceAccountPassword --tenant $serviceAccountTenant

#cd to bicep script

az deployment group create `
--resource-group $resourceGroupName `
--template-file $azureDeployBicepFile `
--parameters  `
  resourcePrefix=$resourceGroupName `
  storageAccountName=$storageAccountName `
  storageAccountFileShareName=$storageAccountFileShareName `
  storageAccountResouceGroupName=$storageAccountResouceGroupName `
  dnsNameForPublicIP=$dnsNameForPublicIP `
  ubuntuOSVersion=$ubuntuOSVersion `
  vmSize=$vmSize `
  location=$resourceGroupLocation `
  authenticationType=$authenticationType `
  adminUsername=$adminUsername `
  adminPasswordOrKey=$adminPasswordOrKey `
  serviceAccountId=$serviceAccountId `
  serviceAccountPassword=$serviceAccountPassword `
  serviceAccountTenant=$serviceAccountTenant `
  azureCloudEnv=$azureCloudEnv `
  newOrExisting=$newOrExisting

