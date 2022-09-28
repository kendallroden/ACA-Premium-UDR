param azureFirewallName string
param azureFirewallIPName string 
param egressRoutingTableName string 
param location string
param vnetName string 
param azureFirewallSubnetProps object
param aks_sp_id string = 'f48ea613-e991-46ef-a7b0-91f8d50b5ce4'

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vnetName
}

// Create Subnet to host Azure Firewall 
resource azureFirewallSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-08-01' = {
  name: '${vnet.name}/${azureFirewallSubnetProps.name}'
  properties: {
    addressPrefix: azureFirewallSubnetProps.properties.addressPrefix
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

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
            id: azureFirewallSubnet.id
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
              name: 'api'
              protocols: [
                'UDP'
                'TCP'
              ]
              sourceAddresses: [
                '*'
              ]
              destinationAddresses: [
                '*'
              ]
              sourceIpGroups: []
              destinationIpGroups: []
              destinationFqdns: []
              destinationPorts: [
                '*'
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
              name: 'all'
              protocols: [
                {
                  protocolType: 'Http'
                  port: 80
                }
                {
                  protocolType: 'Https'
                  port: 443
                }
                {
                  protocolType: 'Mssql'
                  port: 1443
                }
              ]
              fqdnTags: []
              targetFqdns: [
                '*'
              ]
              sourceAddresses: [
                '*'
              ]
              sourceIpGroups: []
            }
            {
              name: 'fqdn'
              protocols: [
                {
                  protocolType: 'Http'
                  port: 80
                }
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              fqdnTags: [
                'AzureKubernetesService'
                'WindowsVirtualDesktop'
                'WindowsUpdate'
                'WindowsDiagnostics'
                'MicrosoftActiveProtectionService'
                'HDInsight'
                'AzureBackup'
                'AppServiceEnvironment'
              ]
              targetFqdns: []
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
