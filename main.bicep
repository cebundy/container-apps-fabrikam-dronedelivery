targetScope = 'resourceGroup'

/*** PARAMETERS ***/

param acrSever string
param containerRegistryUser string
param containerRegistryPassword string
param applicationInsightsInstrumentationKey string
param deliveryCosmosdbDatabaseName string
param deliveryCosmosdbCollectionName string
param deliveryCosmosdbEndpoint string
param deliveryRedisEndpoint string
param deliveryKeyVaultUri string
param droneSchedulerCosmosdbEndpoint string
param droneSchedulerKeyVaultUri string
param wokflowNamespaceEndpoint string
param workflowNamespaceSASName string
param workflowNamespaceSASKey string
param workflowQueueName string
param packageMongodbConnectionString string
param ingestionNamespaceName string
param ingestionNamespaceSASName string
param ingestionNamespaceSASKey string
param ingestionQueueName string

/*** EXISTING RESOURCE GROUP RESOURCES ***/

resource miDelivery 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: 'uid-delivery'
  scope: resourceGroup()
}

resource miDroneScheduler 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: 'uid-dronescheduler'
  scope: resourceGroup()
}

resource miWorkflow 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: 'uid-workflow'
  scope: resourceGroup()
}

resource miPackage 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: 'uid-package'
  scope: resourceGroup()
}

resource miIngestion 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: 'uid-ingestion'
  scope: resourceGroup()
}

/*** RESOURCES ***/

// Drone Delivery App Environment
module env_shipping_dronedelivery 'environment.bicep' = {
  name: 'env-shipping-dronedelivery'
  params: {
    environmentName: 'shipping-dronedelivery'
  }
}

// Delivery App
module ca_delivery 'container-http.bicep' = {
  name: 'ca-delivery'
  params: {
    location: resourceGroup().location
    containerAppName: 'delivery-app'
    containerAppUserAssignedResourceId: miDelivery.id
    environmentId: env_shipping_dronedelivery.outputs.id
    containerImage: '${acrSever}/shipping/delivery:0.1.0'
    containerPort: 8080
    isExternalIngress: false
    containerRegistry: acrSever
    containerRegistryUsername: containerRegistryUser
    containerRegistryPassword: containerRegistryPassword
    secrets: [
        {
          name: 'applicationinsights-instrumentationkey'
          value: applicationInsightsInstrumentationKey
        }
        {
          name: 'containerregistry-password'
          value: containerRegistryPassword
        }
    ]
    env: [
      {
        name: 'ApplicationInsights__InstrumentationKey'
        secretref: 'applicationinsights-instrumentationkey'
      }
      {
        name: 'CosmosDB-Endpoint'
        value: deliveryCosmosdbEndpoint
      }
      {
        name: 'DOCDB_DATABASEID'
        value: deliveryCosmosdbDatabaseName
      }
      {
        name: 'DOCDB_COLLECTIONID'
        value: deliveryCosmosdbCollectionName
      }
      {
        name: 'Redis-Endpoint'
        value: deliveryRedisEndpoint
      }
      {
        name: 'KEY_VAULT_URI'
        value: deliveryKeyVaultUri
      }
      {
        name: 'AZURE_CLIENT_ID'
        value: miDelivery.properties.clientId
      }
    ]
  }
}

// DroneScheduler App
module ca_dronescheduler 'container-http.bicep' = {
  name: 'ca-dronescheduler'
  params: {
    location: resourceGroup().location
    containerAppName: 'dronescheduler-app'
    containerAppUserAssignedResourceId: miDroneScheduler.id
    environmentId: env_shipping_dronedelivery.outputs.id
    containerImage: '${acrSever}/shipping/dronescheduler:0.1.0'
    containerPort: 8080
    isExternalIngress: false
    containerRegistry: acrSever
    containerRegistryUsername: containerRegistryUser
    containerRegistryPassword: containerRegistryPassword
    secrets: [
      {
        name: 'applicationinsights-instrumentationkey'
        value: applicationInsightsInstrumentationKey
      }
      {
        name: 'containerregistry-password'
        value: containerRegistryPassword
      }
    ]
    env: [
      {
        name: 'ApplicationInsights__InstrumentationKey'
        secretref: 'applicationinsights-instrumentationkey'
      }
      {
        name: 'CosmosDBEndpoint'
        value: droneSchedulerCosmosdbEndpoint
      }
      {
        name: 'CosmosDBConnectionMode'
        value: 'Gateway'
      }
      {
        name: 'CosmosDBConnectionProtocol'
        value: 'Https'
      }
      {
        name: 'CosmosDBMaxConnectionsLimit'
        value: '50'
      }
      {
        name: 'CosmosDBMaxParallelism'
        value: '-1'
      }
      {
        name: 'CosmosDBMaxBufferedItemCount'
        value: '0'
      }
      {
        name: 'FeatureManagement__UsePartitionKey'
        value: 'false'
      }
      {
        name: 'COSMOSDB_DATABASEID'
        value: 'invoicing'
      }
      {
        name: 'COSMOSDB_COLLECTIONID'
        value: 'utilization'
      }
      {
        name: 'LOGGING__ApplicationInsights__LOGLEVEL__DEFAULT'
        value: 'Error'
      }
      {
        name: 'KEY_VAULT_URI'
        value: droneSchedulerKeyVaultUri
      }
      {
        name: 'AZURE_CLIENT_ID'
        value: miDroneScheduler.properties.clientId
      }
    ]
  }
}

// Workflow App
module ca_workflow 'container-http.bicep' = {
  name: 'ca-workflow'
  params: {
    location: resourceGroup().location
    containerAppName: 'workflow-app'
    containerAppUserAssignedResourceId: miWorkflow.id
    environmentId: env_shipping_dronedelivery.outputs.id
    containerImage: '${acrSever}/shipping/workflow:0.1.0'
    revisionMode: 'single'
    containerRegistry: acrSever
    containerRegistryUsername: containerRegistryUser
    containerRegistryPassword: containerRegistryPassword
    secrets: [
      {
        name: 'applicationinsights-instrumentationkey'
        value: applicationInsightsInstrumentationKey
      }
      {
        name: 'containerregistry-password'
        value: containerRegistryPassword
      }
      {
        name: 'namespace-sas-key'
        value: workflowNamespaceSASKey
      }
    ]
    env: [
      {
        name: 'ApplicationInsights__InstrumentationKey'
        secretref: 'applicationinsights-instrumentationkey'
      }
      {
        name: 'QueueName'
        value: workflowQueueName
      }
      {
        name: 'QueueEndpoint'
        value: wokflowNamespaceEndpoint
      }
      {
        name: 'QueueAccessPolicyName'
        value: workflowNamespaceSASName
      }
      {
        name: 'QueueAccessPolicyKey'
        secretref: 'namespace-sas-key'
      }
      {
        name: 'HEALTHCHECK_INITIAL_DELAY'
        value: '30000'
      }
      {
        name: 'SERVICE_URI_PACKAGE'
        value: 'https://${ca_package.outputs.fqdn}/api/packages/'
      }
      {
        name: 'SERVICE_URI_DRONE'
        value: 'https://${ca_dronescheduler.outputs.fqdn}/api/DroneDeliveries/'
      }
      {
        name: 'SERVICE_URI_DELIVERY'
        value: 'https://${ca_delivery.outputs.fqdn}/api/Deliveries/'
      }
      {
        name: 'LOGGING__ApplicationInsights__LOGLEVEL__DEFAULT'
        value: 'Error'
      }
      {
        name: 'SERVICEREQUEST__MAXRETRIES'
        value: '3'
      }
      {
        name: 'SERVICEREQUEST__CIRCUITBREAKERTHRESHOLD'
        value: '0.5'
      }
      {
        name: 'SERVICEREQUEST__CIRCUITBREAKERSAMPLINGPERIODSECONDS'
        value: '5'
      }
      {
        name: 'SERVICEREQUEST__CIRCUITBREAKERMINIMUMTHROUGHPUT'
        value: '20'
      }
      {
        name: 'SERVICEREQUEST__CIRCUITBREAKERBREAKDURATION'
        value: '30'
      }
      {
        name: 'SERVICEREQUEST__MAXBULKHEADSIZE'
        value: '100'
      }
      {
        name: 'SERVICEREQUEST__MAXBULKHEADQUEUESIZE'
        value: '25'
      }
    ]
  }
}

// Package App
module ca_package 'container-http.bicep' = {
  name: 'ca-package'
  params: {
    location: resourceGroup().location
    containerAppName: 'package-app'
    containerAppUserAssignedResourceId: miPackage.id
    environmentId: env_shipping_dronedelivery.outputs.id
    containerImage: '${acrSever}/shipping/package:0.1.0'
    containerPort: 80
    isExternalIngress: false
    containerRegistry: acrSever
    containerRegistryUsername: containerRegistryUser
    containerRegistryPassword: containerRegistryPassword
    secrets: [
      {
        name: 'applicationinsights-instrumentationkey'
        value: applicationInsightsInstrumentationKey
      }
      {
        name: 'containerregistry-password'
        value: containerRegistryPassword
      }
      {
        name: 'mongodb-connectrionstring'
        value: packageMongodbConnectionString
      }
    ]
    env: [
      {
        name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
        secretref: 'applicationinsights-instrumentationkey'
      }
      {
        name: 'CONNECTION_STRING'
        secretref: 'mongodb-connectrionstring'
      }
      {
        name: 'COLLECTION_NAME'
        value: 'packages'
      }
      {
        name: 'LOG_LEVEL'
        value: 'error'
      }
      {
        name: 'CONTAINER_NAME'
        value: 'fabrikam-package'
      }
    ]
  }
}

// Ingestion App
module ca_ingestion 'container-http.bicep' = {
  name: 'ca-ingestion'
  params: {
    location: resourceGroup().location
    containerAppName: 'ingestion-app'
    containerAppUserAssignedResourceId: miIngestion.id
    environmentId: env_shipping_dronedelivery.outputs.id
    containerImage: '${acrSever}/shipping/ingestion:0.1.0'
    containerPort: 80
    cpu: '1'
    memory: '2.0Gi'
    isExternalIngress: true
    containerRegistry: acrSever
    containerRegistryUsername: containerRegistryUser
    containerRegistryPassword: containerRegistryPassword
    secrets: [
      {
        name: 'applicationinsights-instrumentationkey'
        value: applicationInsightsInstrumentationKey
      }
      {
        name: 'containerregistry-password'
        value: containerRegistryPassword
      }
      {
        name: 'namespace-sas-key'
        value: ingestionNamespaceSASKey
      }
    ]
    env: [
      {
        name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
        secretref: 'applicationinsights-instrumentationkey'
      }
      {
        name: 'APPINSIGHTS_LOGGERLEVEL'
        value: 'error'
      }
      {
        name: 'CONTAINER_NAME'
        value: 'fabrikam-ingestion'
      }
      {
        name: 'QUEUE_NAMESPACE'
        value: ingestionNamespaceName
      }
      {
        name: 'QUEUE_NAME'
        value: ingestionQueueName
      }
      {
        name: 'QUEUE_KEYNAME'
        value: ingestionNamespaceSASName
      }
      {
        name: 'QUEUE_KEYVALUE'
        secretref: 'namespace-sas-key'
      }
    ]
  }
}

/*** OUTPUTS ***/

output ingestionFqdn string = ca_ingestion.outputs.fqdn
