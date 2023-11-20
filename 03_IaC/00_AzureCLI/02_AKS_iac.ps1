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

#Write-Output "Updating AKS cluster with ACR"
#az aks update -n $AKSClusterName -g $resourceGroupName --attach-acr $acrName

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
#kubectl delete ns teams-recording-bot
# make sure the secret is updated - so delete it if there
#kubectl delete secrets bot-application-secrets --namespace teams-recording-bot

# Create a Public Ip on the MC_RESOURCEGROUP_AKSCLUSTERNAME_AZUREREGION Resource group
#done
#Write-Output "About get public ip: $publicIpName (this should have been created on the previous step)"
#$publicIpAddress = az network public-ip show --resource-group $AKSmgResourceGroup --name $publicIpName --query 'ipAddress'
#Write-Output "Got public ip: $publicIpAddress"


# Starting to setup things

# Create namespace
#done
#Write-Output "About to create teams-recording-bot namespace"
#kubectl create ns teams-recording-bot

# Upload certs
#Write-Host "Uploading certificate to new secret" -ForegroundColor Yellow
#kubectl create secret tls tls-secret --cert=C:\Users\vasalis\Desktop\RecordingBotCerts\tls.crt --key=C:\Users\vasalis\Desktop\RecordingBotCerts\tls.key --namespace teams-recording-bot


# Setup AKS namespace for teams-recording-bot
#done
Write-Output "Creating teams-recording-bot namespace and bot secret that holds BOT_ID, BOT_SECRET, BOT_NAME, Cognitive Service Key and Middleware End Point"
Write-Output "Botname is: $env:botName and Persistance end point is: $env:persistenceEndPoint, Application Insights Key is: $appInsightsKey"

# done
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
#kubectl apply -f "03_IaC\00_AzureCLI\bots-light-k8.yaml" --namespace teams-recording-bot

echo '
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bot
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bot
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  minReadySeconds: 5
  template:
    metadata:
      labels:
        app: bot
    spec:
      nodeSelector:
        "kubernetes.io/os": windows
      containers:
      - name: bot
        image: albotacr.azurecr.io/teams-recording-bot:84
        ports:
        - name: a
          containerPort: 9441
        - name: b
          containerPort: 8445
        - name: c
          containerPort: 9442
        volumeMounts:
        - mountPath: "C:/certs/"
          name: certificate
          readOnly: true
        resources:
          requests:
            cpu: 250m
          limits:
            cpu: "4"
            memory: "4G"
        env:
        - name: AzureSettings__BotName
          valueFrom:
            secretKeyRef:
              name: bot-application-secrets
              key: botName
        - name: AzureSettings__AadAppId
          valueFrom:
            secretKeyRef:
              name: bot-application-secrets
              key: applicationId
        - name: AzureSettings__AadAppSecret
          valueFrom:
            secretKeyRef:
              name: bot-application-secrets
              key: applicationSecret
        - name: AzureSettings__ServiceDnsName
          valueFrom:
            secretKeyRef:
              name: bot-application-secrets
              key: serviceDnsName
        - name: AzureSettings__InstancePublicPort
          value: "8445"
        - name: AzureSettings__InstanceInternalPort
          value: "8445"
        - name: AzureSettings__CallSignalingPort
          value: "9441"
        - name: AzureSettings__PodName
          value: "bot-0"
        - name: AzureSettings__PlaceCallEndpointUrl
          value: https://graph.microsoft.com/v1.0
        - name: AzureSettings__CaptureEvents
          value: "false"
        - name: AzureSettings__EventsFolder
          value: "events"
        - name: AzureSettings__MediaFolder
          value: "archive"
        - name: AzureSettings__TopicKey
          value: ""
        - name: AzureSettings__TopicName
          value: ""
        - name: AzureSettings__RegionName
          value: ""
        - name: AzureSettings__IsStereo
          value: "false"
        - name: AzureSettings__WAVSampleRate
          value: "0"
        - name: AzureSettings__WAVQuality
          value: "100"
        - name: AzureSettings__AzureCognitiveKey
          valueFrom:
            secretKeyRef:
              name: bot-application-secrets
              key: azureCognitiveKey
        - name: AzureSettings__AzureCognitiveRegion
          valueFrom:
            secretKeyRef:
              name: bot-application-secrets
              key: azureCognitiveRegion
        - name: AzureSettings__PersistenceEndPoint
          valueFrom:
            secretKeyRef:
              name: bot-application-secrets
              key: persistenceEndPoint
        - name: AzureSettings__AppInsightsKey
          valueFrom:
            secretKeyRef:
              name: bot-application-secrets
              key: appInsightsKey
      volumes:
      - name: certificate
        secret:
          secretName: tls-secret

---
kind: Service
apiVersion: v1
metadata:
  name: bot-service
spec:
  # LoadBalancer type to allow external access to multiple ports
  type: LoadBalancer
  selector:
    # Will deliver external traffic to the pod holding each of our containers
    app: bot
  ports:
    - name: mediastream
      protocol: TCP
      port: 443
      targetPort: 9441
    - name: mediastream2
      protocol: TCP
      port: 8445
      targetPort: 8445
    - name: mediastreamplusone
      protocol: TCP
      port: 9442
      targetPort: 9442

' | kubectl apply -f - --namespace teams-recording-bot
