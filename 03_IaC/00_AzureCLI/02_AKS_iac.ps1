# Helping variables
$botSubDomain = $env:botSubDomain
$azureLocation = $env:azureLocation
$projectPrefix = $env:projectPrefix
$resourceGroupName = $projectPrefix +"_rg"

$AKSClusterName = "recBotAKSCluster2"
# TODO: remove this and make better
$PASSWORD_WIN="AbcABC123!@#123456"

$AKSmgResourceGroup = "MC_"+$resourceGroupName+"_"+"$AKSClusterName"+"_"+$azureLocation
$publicIpName = "myRecBotPublicIP"

$acrName = $env:acrName

Write-Output "(Got from ENV): RG: $resourceGroupName, MC rg: $AKSmgResourceGroup, location: $azureLocation"
Write-Output "Environment Azure CL: $(az --version)"

# Create the resource group
Write-Output "About to create resource group: $resourceGroupName" 
az group create -l $azureLocation -n $resourceGroupName

# Create Application Insights for the recording bot
Write-Output "About to create Application Insights for rec bot."
az extension add --name application-insights
az monitor app-insights component create -a "botAI" -l $azureLocation -g $resourceGroupName
$appInsightsKey = az monitor app-insights component show --app "botAI" -g $resourceGroupName --query 'instrumentationKey'
Write-Output "Got app insights key: $appInsightsKey"


# Create the AKS Cluster
Write-Output "About to create AKS cluster: $resourceGroupName"
Write-Output "az aks create --resource-group $resourceGroupName --name $AKSClusterName --node-count 1 --enable-addons monitoring --generate-ssh-keys --windows-admin-password $PASSWORD_WIN --windows-admin-username azureuser --vm-set-type VirtualMachineScaleSets --network-plugin azure --service-principal $env:SP_ID --client-secret $env:SP_SECRET"

az aks create --resource-group $resourceGroupName --name $AKSClusterName --node-count 1 --enable-addons monitoring --generate-ssh-keys --windows-admin-password $PASSWORD_WIN --windows-admin-username azureuser --vm-set-type VirtualMachineScaleSets --network-plugin azure --service-principal $env:SP_ID --client-secret $env:SP_SECRET

# Add the Windows Node pool
Write-Output "About to create AKS windows pool: $resourceGroupName"
az aks nodepool add --resource-group $resourceGroupName --cluster-name $AKSClusterName --os-type Windows --name scale --node-count 1 --node-vm-size Standard_DS3_v2

# Create the Azure Container Registry to hold the bot's docker image (if not already there)
Write-Output "About to create ACR: $acrName"
az acr create --resource-group $resourceGroupName --name $acrName --sku Basic --admin-enabled true

Write-Output "Updating AKS cluster with ACR"
az aks update -n $AKSClusterName -g $resourceGroupName --attach-acr $acrName

# Move the Public IP address to MC_ resource group. 
# This is needed in order for the load balancer to get assigned with the Public IP, otherwise you might end up in a "pending" state.
#Write-Output "Move Public IP resource to MC_ resource group"
#$publicIpAddressId = az network public-ip show --resource-group $resourceGroupName --name $publicIpName --query 'id'
#az resource move --destination-group $AKSmgResourceGroup --ids $publicIpAddressId

# Starting with basic setup
Write-Output "Getting AKS credentials for cluster: $AKSClusterName"
az aks get-credentials --resource-group $resourceGroupName --name $AKSClusterName

# Make sure everything is clean before doing things
# on first run this will give errors, but when running it again it will restore things to initial state.

# delete namespace to clean things up.
kubectl delete ns teams-recording-bot
# make sure the secret is updated - so delete it if there
kubectl delete secrets bot-application-secrets --namespace teams-recording-bot

# Create a Public Ip on the MC_RESOURCEGROUP_AKSCLUSTERNAME_AZUREREGION Resource group
Write-Output "About get public ip: $publicIpName (this should have been created on the previous step)"
$publicIpAddress = az network public-ip show --resource-group $AKSmgResourceGroup --name $publicIpName --query 'ipAddress'
Write-Output "Got public ip: $publicIpAddress"


# Starting to setup things

# Create namespace
Write-Output "About to create teams-recording-bot namespace"
kubectl create ns teams-recording-bot

# Upload certs
Write-Host "Uploading certificate to new secret" -ForegroundColor Yellow
kubectl create secret tls tls-secret --cert=C:\Users\vasalis\Desktop\RecordingBotCerts\tls.crt --key=C:\Users\vasalis\Desktop\RecordingBotCerts\tls.key --namespace teams-recording-bot


# Setup AKS namespace for teams-recording-bot
Write-Output "Creating teams-recording-bot namespace and bot secret that holds BOT_ID, BOT_SECRET, BOT_NAME, Cognitive Service Key and Middleware End Point"
Write-Output "Botname is: $env:botName and Persistance end point is: $env:persistenceEndPoint, Application Insights Key is: $appInsightsKey"

kubectl create secret generic bot-application-secrets --namespace teams-recording-bot --from-literal=applicationId=$env:BOT_ID `
 --from-literal=applicationSecret=$env:BOT_SECRET `
 --from-literal=botName=$env:botName `
 --from-literal=azureCognitiveKey=$env:azureCognitiveKey `
 --from-literal=persistenceEndPoint=$env:persistenceEndPoint `
 --from-literal=azureCognitiveRegion=$azureLocation `
 --from-literal=appInsightsKey=$appInsightsKey `
 --from-literal=serviceDnsName=$botSubDomain

# Create bot & NLB
Write-Host "Applying bot YAML configuration" -ForegroundColor Yellow
kubectl apply -f .\bots-light-k8.yaml --namespace teams-recording-bot