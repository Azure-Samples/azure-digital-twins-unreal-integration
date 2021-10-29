param userId string
param appRegId string
@secure()
param appRegPassword string
param servicePrincipalObjectId string
param tenantId string = subscription().tenantId
param utcValue string = utcNow()
param repoOrgName string
param repoName string
param repoBranchName string
param unique string = substring(uniqueString(resourceGroup().id), 0, 2)

var location = resourceGroup().location
var iotHubName = 'iothub-${unique}'
var adtName = 'adt-${unique}'
var signalrName = 'signalr-${unique}'
var serverFarmName = 'farm-${unique}'
var storageName = 'store${unique}'
//var eventGridName = 'eg${unique}'
var funcAppName = 'funcapp-${unique}'
var webAppName = 'webapp-${unique}'
var eventGridIngestName = 'egingest-${unique}'
var ingestFuncName = 'IoTHubIngest'
var signalrFuncName = 'broadcast'
var adtChangeLogTopicName = 'adtchangelogtopic-${unique}'
var ehNamespace = 'eventhubs-${unique}'
var ehNamespaceAuthRule = 'RootManageSharedAccessKey'
var ehTwinsName = 'ehtwin'
var ehTwinsAuthRule = 'twinsauthrule'
var ehTsiName = 'ehtsi'
var ehTsiAuthRule = 'tsiauthrule'
var adtEhEndpoint = 'twinendpoint'
var adtEhRoute = 'twinroute'
var adtEgEndpoint = 'changelogendpoint'
var adtEgRoute = 'changelogroute'
var tsiName = 'tsi-${unique}'
var tsiStorageName = 'tsistr${unique}'
var tsiSkuName = 'L1'
var tsiCapacity = 1
var tsiTimeSeriesId = '$dtId'
var tsiWarmStoreDataRetention = 'P7D'
var tsiEventSourceName = ehTsiName

// Update later when repo becomes public
var funcPackageUri = 'https://github.com/${repoOrgName}/${repoName}/raw/${repoBranchName}/function-code/UnrealIoTIngest/funcapp-deploy.zip'
var webAppPackageUri = 'https://github.com/${repoOrgName}/${repoName}/raw/${repoBranchName}/webapp-code/TsiWebApp/webapp-deploy.zip'
var azDtCreateScriptUri = 'https://github.com/${repoOrgName}/${repoName}/raw/${repoBranchName}/deployment/scripts/az-dt-route-create.sh'

var identityName = 'scriptidentity-${unique}'
var rgRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
var rgRoleDefinitionName = guid(identity.id, rgRoleDefinitionId, resourceGroup().id)
var ADTroleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'bcd981a7-7f74-457b-83e1-cceb9e632ffe')
var ADTroleDefinitionName = guid(identity.id, ADTroleDefinitionId, resourceGroup().id)
var ADTroleDefinitionAppName = guid(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', funcAppName), ADTroleDefinitionId, resourceGroup().id)
var ADTRoleDefinitionUserName = guid(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', userId), ADTroleDefinitionId, resourceGroup().id)
var ADTRoleDefinitionAppRegName = guid(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', appRegId), ADTroleDefinitionId, resourceGroup().id)

var tags = {
  type: 'adt-unreal-demo'
  deploymentId: unique
}

// create user assigned managed identity for this script to run under
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: identityName
  location: location
  tags: tags
}

// create event hub namepace
resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-01-01-preview' = {
  name: ehNamespace
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 1
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  properties: {
    isAutoInflateEnabled: false
    maximumThroughputUnits: 0
    kafkaEnabled: true
    zoneRedundant: false
  }
  dependsOn: [
    identity
  ]
}

// event hub namespace root authorization rule
resource eventHubRootRule 'Microsoft.EventHub/namespaces/authorizationRules@2021-01-01-preview' = {
  name: '${eventHubNamespace.name}/${ehNamespaceAuthRule}'
  properties: {
    rights: [
      'Send'
      'Listen'
      'Manage'
    ]
  }
}

// event hub (used by ADT)
resource twinsEventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-01-01-preview' = {
  name: '${eventHubNamespace.name}/${ehTwinsName}'
  properties: {
    messageRetentionInDays: 7
    partitionCount: 4
  }
  // event hub authorization rule (used by ADT)
  resource twinsEventHubRule 'authorizationRules@2021-01-01-preview' = {
    name: ehTwinsAuthRule
    properties: {
      rights: [
        'Send'
        'Listen'
      ]
    }
  }
  // event hub consumer group (used by ADT)
  resource twinsEventHubConsumerGroup 'consumergroups@2021-01-01-preview' = {
    name: '$Default'
    properties: {}
  }
}

// event hub (used by TSI)
resource tsiEventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-01-01-preview' = {
  name: '${eventHubNamespace.name}/${ehTsiName}'
  properties: {
    messageRetentionInDays: 7
    partitionCount: 4
  }
  // event hub authorization rule (used by TSI)
  resource tsiEventHubRule 'authorizationRules@2021-01-01-preview' = {
    name: ehTsiAuthRule
    properties: {
      rights: [
        'Send'
        'Listen'
      ]
    }
  }
  // event hub consumer group (used by TSI)
  resource tsiEventHubConsumerGroup 'consumergroups@2021-01-01-preview' = {
    name: '$Default'
    properties: {}
  }
}

// create iot hub
resource iot 'microsoft.devices/iotHubs@2020-03-01' = {
  name: iotHubName
  location: location
  tags: tags
  sku: {
    name: 'S1'
    capacity: 1
  }
  properties: {
    eventHubEndpoints: {
      events: {
        retentionTimeInDays: 1
        partitionCount: 4
      }
    }
    routing: {
      routes: [
        {
          name: 'default'
          source: 'DeviceMessages'
          condition: 'true'
          endpointNames: [
            'events'
          ]
          isEnabled: true
        }
      ]
    }
  }
  dependsOn: [
    funcAppDeploy //hackhack - make as much as possible 'dependon' the azure function app to deal w/ some timing issues
  ]
}

// create storage account (used by the azure function app)
resource storage 'Microsoft.Storage/storageAccounts@2018-02-01' = {
  name: storageName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    isHnsEnabled: false
  }
}

// create ADT instance
resource adt 'Microsoft.DigitalTwins/digitalTwinsInstances@2020-12-01' = {
  name: adtName
  location: location
  tags: tags
  properties: {}
  dependsOn: [
    identity
    twinsEventHub
  ]
  // event hub endpoint
  resource adtEventHubEndpoint 'endpoints@2020-12-01' = {
    name: adtEhEndpoint
    properties: {
      authenticationType: 'KeyBased'
      endpointType: 'EventHub'
      connectionStringPrimaryKey: '${listKeys(ehTwinsAuthRule, '2021-01-01-preview').primaryConnectionString}'
      connectionStringSecondaryKey: '${listKeys(ehTwinsAuthRule, '2021-01-01-preview').secondaryConnectionString}'
    }
  }
  // event grid endpoint
  resource adtEventGridEndpoint 'endpoints@2020-12-01' = {
    name: adtEgEndpoint
    properties: {
      endpointType: 'EventGrid'
      authenticationType: 'KeyBased'
      TopicEndpoint: eventGridADTChangeLogTopic.properties.endpoint
      accessKey1: '${listKeys(adtChangeLogTopicName, '2020-10-15-preview').key1}'
      accessKey2:'${listKeys(adtChangeLogTopicName, '2020-10-15-preview').key2}'
    }
  }
}

// create signalr instance
resource signalr 'Microsoft.SignalRService/signalR@2020-07-01-preview' = {
  name: signalrName
  location: location
  tags: tags
  sku: {
    name: 'Standard_S1'
    capacity: 1
    tier: 'Standard'
  }
  properties: {
    cors: {
      allowedOrigins: [
        '*'
      ]
    }
    features: [
      {
        flag: 'ServiceMode'
        value: 'Serverless'
      }
    ]
  }
}

// App Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: serverFarmName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForQuery: 'Enabled'
    publicNetworkAccessForIngestion: 'Enabled'
  }
}

// create App Plan aka "server farm"
resource appserver 'Microsoft.Web/serverfarms@2021-01-15' = {
  name: serverFarmName
  location: location
  tags: tags
  kind: 'app'
  sku: {
    name: 'B1'
    tier: 'Basic'
    size: 'B1'
    family: 'B'
    capacity: 1
  }
}

// create Function app for hosting the IoTHub ingress and SignalR egress
resource funcApp 'Microsoft.Web/sites@2021-01-15' = {
  name: funcAppName
  location: location
  tags: tags
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageName};AccountKey=${listKeys(storageName, '2019-06-01').keys[0].value}'
        }
        {
          name: 'ADT_SERVICE_URL'
          value: 'https://${adt.properties.hostName}'
        }
        {
          name: 'AzureSignalRConnectionString'
          value: 'Endpoint=https://${signalrName}.service.signalr.net;AccessKey=${listKeys(signalrName, providers('Microsoft.SignalRService', 'SignalR').apiVersions[0]).primaryKey};Version=1.0;'
        }
        {
          name: 'EventHubAppSetting-Twins'
          value: listKeys(ehTwinsAuthRule, '2021-01-01-preview').primaryConnectionString
        }
        {
          name: 'EventHubAppSetting-Tsi'
          value: listKeys(ehTsiAuthRule, '2021-01-01-preview').primaryConnectionString
        }
      ]
      alwaysOn: true
      cors: {
        supportCredentials: true
        allowedOrigins: [
          'http://localhost:3000'
          'https://functions.azure.com'
          'https://functions-staging.azure.com'
          'https://functions-next.azure.com'
        ]
      }
    }
    serverFarmId: appserver.id
    clientAffinityEnabled: false
  }
  dependsOn: [
    adt
    storage
    signalr
    identity
    tsiEventHub
    twinsEventHub
  ]
}

// deploy the code for the two azure functionss (iot hub ingest and signalr)
resource funcAppDeploy 'Microsoft.Web/sites/extensions@2020-12-01' = {
  name: '${funcApp.name}/MSDeploy'
  properties: {
    packageUri: funcPackageUri
  }
  dependsOn: [
    funcApp
  ]
}

// event grid topic that iot hub posts telemetry messages to
resource eventGridIngestTopic 'Microsoft.EventGrid/systemTopics@2020-04-01-preview' = {
  name: eventGridIngestName
  location: location
  tags: tags
  properties: {
    source: iot.id
    topicType: 'microsoft.devices.iothubs'
  }
  dependsOn: [
    iot
    funcAppDeploy
  ]
}

// event grid subscription for iot hub telemetry data (posts to iot hub ingestion function)
resource eventGridIoTHubIngest 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2020-04-01-preview' = {
  name: '${eventGridIngestTopic.name}/${ingestFuncName}'
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: '${funcApp.id}/functions/${ingestFuncName}'
        maxEventsPerBatch: 1
        preferredBatchSizeInKilobytes: 64
      }
    }
    eventDeliverySchema: 'EventGridSchema'
    filter: {
      includedEventTypes: [
        'Microsoft.Devices.DeviceTelemetry'
      ]
    }
  }
  dependsOn: [
    iot
    funcAppDeploy
    eventGridIngestTopic
  ]
}

// Event Grid topic for ADT twin change notifications
resource eventGridADTChangeLogTopic 'Microsoft.EventGrid/topics@2020-10-15-preview' = {
  name: adtChangeLogTopicName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  kind: 'Azure'
  identity: {
    type: 'None'
  }
  properties: {
    inputSchema: 'EventGridSchema'
    publicNetworkAccess: 'Enabled'
  }
  dependsOn: [
    funcAppDeploy
    iot //hackhack - make this run as late as possible because of a tricky timing issue w/ the /broadcast function
    eventGridIoTHubIngest
    rgroledef
    adtroledef
    adtroledefapp
    ADTRoleDefinitionUser
    ADTRoleDefinitionAppReg
  ]
}

// EventGrid subscription for ADT twin changes (invokes function to post to signalr)
resource eventGridSignalr 'Microsoft.EventGrid/eventSubscriptions@2020-06-01' = {
  name: signalrFuncName
  scope: eventGridADTChangeLogTopic
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: '${funcApp.id}/functions/${signalrFuncName}'
        maxEventsPerBatch: 1
        preferredBatchSizeInKilobytes: 64
      }
    }
  }
  dependsOn: [
    funcAppDeploy
    eventGridADTChangeLogTopic
  ]
}

// add RBAC "owner" role to resource group - for the script
resource rgroledef 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: rgRoleDefinitionName
  properties: {
    roleDefinitionId: rgRoleDefinitionId
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// add "Digital Twins Data Owner" role to ADT instance for our deployment - for the script
resource adtroledef 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: ADTroleDefinitionName
  properties: {
    roleDefinitionId: ADTroleDefinitionId
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// add "Digital Twins Data Owner" permissions to teh system identity of the Azure Functions
resource adtroledefapp 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: ADTroleDefinitionAppName
  properties: {
    roleDefinitionId: ADTroleDefinitionId
    principalId: reference(funcApp.id, '2019-08-01', 'Full').identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// assign ADT data role owner permissions to the user
resource ADTRoleDefinitionUser 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: ADTRoleDefinitionUserName
  properties: {
    roleDefinitionId: ADTroleDefinitionId
    principalId: userId
    principalType: 'User'
  }
}

// assign ADT data role owner permissions to the app registration
resource ADTRoleDefinitionAppReg 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: ADTRoleDefinitionAppRegName
  properties: {
    roleDefinitionId: ADTroleDefinitionId
    principalId: servicePrincipalObjectId
    principalType: 'ServicePrincipal'
  }
}

// create storage account (used by the azure time series insights)
resource tsiStorageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: tsiStorageName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    isHnsEnabled: false
  }
}

// create time series insights environment
resource tsiEnvironment 'Microsoft.TimeSeriesInsights/environments@2020-05-15' = {
  name: tsiName
  location: location
  tags: tags
  dependsOn: [
    tsiEventHub
  ]
  sku: {
    name: tsiSkuName
    capacity: tsiCapacity
  }
  kind: 'Gen2'
  properties: {
    storageConfiguration: {
      accountName: tsiStorageName
      managementKey: '${listKeys(tsiStorageName, '2019-06-01').keys[0].value}'
    }
    timeSeriesIdProperties: [
      {
        name: tsiTimeSeriesId
        type: 'String'
      }
    ]
    warmStoreConfiguration: {
      dataRetention: tsiWarmStoreDataRetention
    }
  }
  // user TSI access policy
  resource tsiUserPolicy 'accessPolicies@2020-05-15' = {
    name: 'ownerAccessPolicy'
    properties: {
      principalObjectId: userId
      roles: [
        'Reader'
        'Contributor'
      ]
    }
  }
  // service principal TSI reader access policy
  resource tsiAppRegPolicy 'accessPolicies@2020-05-15' = {
    name: 'appRegAccessPolicy'
    properties: {
      principalObjectId: servicePrincipalObjectId
      roles: [
        'Reader'
      ]
    }
  }
}

// TSI event hub event source
resource tsiEventSource 'Microsoft.TimeSeriesInsights/environments/eventSources@2020-05-15' = {
  name: '${tsiEnvironment.name}/${tsiEventSourceName}'
  location: location
  tags: tags
  kind: 'Microsoft.EventHub'
  properties: {
    eventSourceResourceId: '${tsiEventHub.id}'
    eventHubName: ehTsiName
    serviceBusNamespace: '${eventHubNamespace.name}'
    consumerGroupName: '$Default'
    keyName: ehTsiAuthRule
    sharedAccessKey: listKeys(ehTsiAuthRule, '2021-01-01-preview').primaryKey
  }
}

// create web app to visualize TSI data
resource webApp 'Microsoft.Web/sites@2021-01-15' = {
  name: webAppName
  location: location
  tags: tags
  kind: 'app'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'AAD_LOGIN_URL'
          value: 'https://login.windows.net'
        }
        {
          name: 'CLIENT_ID'
          value: appRegId
        }
        {
          name: 'CLIENT_SECRET'
          value: appRegPassword
        }
        {
          name: 'RESOURCE_URI'
          value: '120d688d-1518-4cf7-bd38-182f158850b6'
        }
        {
          name: 'SENSOR_COUNT'
          value: '4'
        }
        {
          name: 'TENANT_ID'
          value: tenantId
        }
        {
          name: 'TSI_ENV_FQDN'
          value: '${tsiEnvironment.properties.dataAccessId}.env.timeseries.azure.com'
        }
      ]
      alwaysOn: true
      cors: {
        supportCredentials: true
        allowedOrigins: [
          'http://localhost:3000'
        ]
      }
    }
    serverFarmId: appserver.id
    clientAffinityEnabled: false
  }
  dependsOn: [
    storage
    identity
    appserver
    tsiEnvironment
  ]
}

// deploy the code for the web app
resource webAppDeploy 'Microsoft.Web/sites/extensions@2020-12-01' = {
  name: '${webApp.name}/MSDeploy'
  properties: {
    packageUri: webAppPackageUri
  }
  dependsOn: [
    webApp
  ]
}
  
// post deployment script: ADT event hub route
resource adtEventHubRoute 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'adtEventHubRoute'
  location: location
  tags: tags
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: utcValue
    azCliVersion: '2.15.0'
    arguments: '${adt.name} ${resourceGroup().name} ${adtEhEndpoint} ${adtEhRoute}'
    primaryScriptUri: azDtCreateScriptUri
    supportingScriptUris: []
    timeout: 'PT30M'
    cleanupPreference: 'OnExpiration'
    retentionInterval: 'P1D'
  }
  dependsOn: [
    iot
    adt
    rgroledef
    eventGridADTChangeLogTopic
  ]
}

// post deployment script: ADT event grid route
resource azDtEventGridRoute 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'azDtEventGridRoute'
  location: location
  tags: tags
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: utcValue
    azCliVersion: '2.15.0'
    arguments: '${adt.name} ${resourceGroup().name} ${adtEgEndpoint} ${adtEgRoute}'
    primaryScriptUri: azDtCreateScriptUri
    supportingScriptUris: []
    timeout: 'PT30M'
    cleanupPreference: 'OnExpiration'
    retentionInterval: 'P1D'
  }
  dependsOn: [
    iot
    adt
    rgroledef
    eventGridADTChangeLogTopic
  ]
}

output importantInfo object = {
  appId: appRegId
  password: appRegPassword
  tenant: tenantId
  iotHubName: iotHubName
  signalRNegotiatePath: '${funcApp.name}.azurewebsites.net/api/'
  adtHostName: replace('${adt.properties.hostName}', 'https://', '') //remove https:// from the 
  tsiEnvFqdn: 'https://insights.timeseries.azure.com/?environmentId=${tsiEnvironment.properties.dataAccessId}'
  tsiWebAppPath: 'https://${webApp.properties.hostNames[0]}'
}
