param azureFirewallName string
param azureFirewallIPName string 
param egressRoutingTableName string 
param location string
param azureFirewallSubnetId string 
param aks_sp_id string = 'f48ea613-e991-46ef-a7b0-91f8d50b5ce4'

//If using NorthUSStage, use CentralUS
param containerAppEnvLocation string = location

//AKS FQDN and service tag dependencies. For the region-specific FQDN and service tags, we use the Container App Environment location, minus any spaces
var containerAppEnvLocationNoSpace = replace(containerAppEnvLocation, ' ', '')
var fqdnHttpsAKS = '*.hcp.${containerAppEnvLocationNoSpace}.azmk8s.io'
var azureCloudRegionServiceTag = 'AzureCloud.${containerAppEnvLocationNoSpace}'

// Create a Public IP for Azure Firewall 
resource azureFirewallPublicIP 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: azureFirewallIPName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}

// Create Azure Firewall 
resource azureFirewall 'Microsoft.Network/azureFirewalls@2020-11-01' = {
  name: azureFirewallName
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    threatIntelMode: 'Alert'
    additionalProperties: {
      'Network.DNS.EnableProxy': 'true'
    }
    ipConfigurations: [
      {
        name: 'egress-fwconfig'
        properties: {
          publicIPAddress: {
            id: azureFirewallPublicIP.id
          }
          subnet: {
            id: azureFirewallSubnetId
          }
        }
      }
    ]
    networkRuleCollections: [
      {
        name: 'aksfwnr'
        properties: {
          priority: 100
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'apiTCP'
              protocols: [
                'TCP'
              ]
              sourceAddresses: [
                '*'
              ]
              destinationAddresses: [
                'AzureCloud'
              ]
              sourceIpGroups: []
              destinationIpGroups: []
              destinationFqdns: []
              destinationPorts: [
                '443'
				'9000'
              ]
            }
            {
              name: 'apiUDP'
              protocols: [
                'UDP'
              ]
              sourceAddresses: [
                '*'
              ]
              destinationAddresses: [
                'AzureCloud'
              ]
              sourceIpGroups: []
              destinationIpGroups: []
              destinationFqdns: []
              destinationPorts: [
                '1194'
              ]
            }
            {
              name: 'time'
              protocols: [
                'UDP'
              ]
              sourceAddresses: [
                '*'
              ]
              destinationAddresses: []
              sourceIpGroups: []
              destinationIpGroups: []
              destinationFqdns: ['ntp.ubuntu.com']
              destinationPorts: [
                '123'
              ]
            }
          ]
        }
      }
    ]
    applicationRuleCollections: [
      {
        name: 'aksfwar'
        properties: {
          priority: 100
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'api'
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              fqdnTags: []
              targetFqdns: [
                '${fqdnHttpsAKS}'
				'mcr.microsoft.com'
				'*.data.mcr.microsoft.com'
				'management.azure.com'
				'login.microsoftonline.com'
				'packages.microsoft.com'
				'acs-mirror.azureedge.net'
				'dc.services.visualstudio.com'
				'*.ods.opinsights.azure.com'
				'*.oms.opinsights.azure.com'
				'*.monitoring.azure.com'
              ]
              sourceAddresses: [
                '*'
              ]
              sourceIpGroups: []
            }
          ]
        }
      }
    ]
    natRuleCollections: []
  }
}


resource egressRoutingTable 'Microsoft.Network/routeTables@2020-11-01' = {
  name: egressRoutingTableName
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'egress-fwrn'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
          hasBgpOverride: false
        }
      }
      {
        name: 'egress-fwinternet'
        properties: {
          addressPrefix: '${azureFirewallPublicIP.properties.ipAddress}/32'
          nextHopType: 'Internet'
          hasBgpOverride: false
        }
      }
    ]
  }
}
 
@description('This is the built-in Network Contributor role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor')
resource networkContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: resourceGroup()
  name: '4d97b98b-1d4f-4787-a291-c67834d212e7'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, networkContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: networkContributorRoleDefinition.id
    principalId: aks_sp_id
    principalType: 'ServicePrincipal'
  }
}

output virtualAppliancePublicIP string = azureFirewallPublicIP.properties.ipAddress
