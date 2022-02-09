@description('Batch Account Name')
param batchAccountName string = '${toLower(uniqueString(resourceGroup().id))}batch'

@description('Name of the Node Pool')
param nodePoolName string

@description('Size of the Node Pool VMs')
@allowed([
  'Standard_NV6'
  'Standard_NV4as_v4'
  'Standard_NV12s_v3'
])
param vmSize string

@description('Storage Account type')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_ZRS'
  'Premium_LRS'
])
param storageAccountsku string = 'Standard_LRS'

@description('Location for all resources.')
param location string = resourceGroup().location

var uniqueStorageName = '${uniqueString(resourceGroup().id)}storage'

resource exampleStorage 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: uniqueStorageName
  location: location
  sku: {
    name: storageAccountsku
  }
  kind: 'StorageV2'
  tags: {
    ObjectName: uniqueStorageName
  }
  properties: {}
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' = {
   parent: exampleStorage
   name: 'default'
}

resource startupContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' = {
  name: 'nodepool-startup'
  parent: blobService
}

resource appContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' = {
  name: 'app1'
  parent: blobService
}

resource outputContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' = {
  name: 'output'
  parent: blobService
}

resource exampleBatch 'Microsoft.Batch/batchAccounts@2021-06-01' = {
  name: batchAccountName
  location: location
  tags: {
    ObjectName: batchAccountName
  }
  properties: {
    autoStorage: {
      storageAccountId: exampleStorage.id
    }
    poolAllocationMode: 'BatchService'
  }
}

resource examplePool 'Microsoft.Batch/batchAccounts/pools@2021-06-01' = {
  name: nodePoolName
  parent: exampleBatch
  properties:{
    vmSize: vmSize
    interNodeCommunication: 'Disabled'
    taskSlotsPerNode: 1
    taskSchedulingPolicy: {
       nodeFillType: 'Pack'
    }
    deploymentConfiguration: {
      virtualMachineConfiguration: {
        imageReference: {
          publisher: 'microsoftwindowsserver'
          offer: 'windowsserver'
          sku: '2019-datacenter-smalldisk'
          version: 'latest'
        }
        nodeAgentSkuId: 'batch.node.windows amd64'
      }
    }
    applicationPackages: [
     // batchApp1

    ]
  scaleSettings: {
    fixedScale: {
       targetDedicatedNodes: 1
       nodeDeallocationOption: 'TaskCompletion'
    }
  }
   startTask: {
     commandLine: 'powershell.exe -file ./startup.ps1'
     resourceFiles: [
       {
         autoStorageContainerName: 'nodepool-startup'
       }
     ]
   }
  }
}
/*
resource batchApp1 'Microsoft.Batch/batchAccounts/applications@2021-06-01' = {
   name: 'renderingApp'
   parent: exampleBatch
   properties: {
     displayName: 'renderingApp'
     allowUpdates: true
     defaultVersion: '1.0'
   }
}

resource batchApp1Version 'Microsoft.Batch/batchAccounts/applications/versions@2021-06-01' = {
  name: '1.0'
  parent: batchApp1
   properties: {
     
   }
}
*/
output storageAccountName string = exampleStorage.name
output batchAccountName string = batchAccountName

