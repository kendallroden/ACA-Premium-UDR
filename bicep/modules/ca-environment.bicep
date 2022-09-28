param containerAppsEnvName string
param logAnalyticsWorkspaceName string = 'logs-${containerAppsEnvName}'
param location string = 'australiaeast'
param vnetName string 
param containerAppsSubnetProps object
param egressRoutingTableName string 
param virtualNetworkApplianceIP string 

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vnetName
}
resource egressRoutingTable 'Microsoft.Network/routeTables@2020-11-01' existing = {
  name: egressRoutingTableName
}

// Create Subnet to host Azure Container Apps environment  
resource containerAppsSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-08-01' = {
  name: '${vnet.name}/${containerAppsSubnetProps.name}'
  properties: {
    routeTable: {
      id: egressRoutingTable.id
    }
    addressPrefix: containerAppsSubnetProps.properties.addressPrefix
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

resource environment 'Microsoft.App/managedEnvironments@2022-06-01-preview' = {
  name: containerAppsEnvName
  location: 'northcentralusstage'
  sku: {
    name: 'Premium'
  }
  properties: {
    workloadProfiles: [
      {
        workloadProfileType: 'GP1'
        minimumCount: 3
        maximumCount: 5
      }
    ]
    vnetConfiguration: {
      internal: true
      infrastructureSubnetId: containerAppsSubnet.id
      dockerBridgeCidr: '10.2.0.1/16'
      platformReservedCidr: '10.1.0.0/16'
      platformReservedDnsIP: '10.1.0.2'
      outboundSettings: {
        outBoundType: 'userDefinedRouting'
        virtualNetworkApplianceIP: virtualNetworkApplianceIP
      }
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    zoneRedundant: false
  }
}

output cappsEnvId string = environment.id
output defaultDomain string = environment.properties.defaultDomain
output staticIP string = environment.properties.staticIp 
