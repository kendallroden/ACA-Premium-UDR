param location string = resourceGroup().location
param uniqueSeed string = '${subscription().subscriptionId}-${resourceGroup().name}'
param uniqueSuffix string = 'da-${uniqueString(uniqueSeed)}'
param containerAppsEnvName string = 'env-${uniqueSuffix}'
param logAnalyticsWorkspaceName string = 'log-${uniqueSuffix}'
param vnetName string = 'vnet-${uniqueSuffix}'
param vnetPrefix string = '10.0.0.0/16'
param azureFirewallName string = 'azureFirewall'
param azureFirewallIPName string = 'azureFirewallPublicIP'
param egressRoutingTableName string = 'udrRoutingTable'
param appGatewayName string = 'appGateway'
param appGatewayIPName string = 'appGatewayPublicIP'

var containerAppsSubnet = {
  name: 'ContainerAppsSubnet'
  properties: {
    addressPrefix: '10.0.0.0/23'
  }
}

// Azure Firewall Subnet name CANNOT be changed
var firewallSubnet = {
  name: 'AzureFirewallSubnet'
  properties: {
    addressPrefix: '10.0.2.0/24'
  }
}

var appGatewaySubnet = {
  name: 'AppGatewaySubnet'
  properties: {
    addressPrefix: '10.0.3.0/24'
  }
}

var subnets = [
  appGatewaySubnet
  firewallSubnet
]

// Deploy an Azure Virtual Network 
module vnetModule 'modules/vnet.bicep' = {
  name: '${deployment().name}--vnet'
  params: {
    location: location
    vnetName: vnetName
    vnetPrefix: vnetPrefix
    subnets: subnets
  }
}

// Deploy and configure Azure Firewall 
module azureFirewallModule 'modules/azure-firewall.bicep' = {
  name: '${deployment().name}--azureFirewall'
  dependsOn: [
    vnetModule
  ]
  params: {
    location: location
    azureFirewallSubnetId: '${vnetModule.outputs.vnetId}/subnets/${firewallSubnet.name}'
    azureFirewallIPName: azureFirewallIPName
    azureFirewallName: azureFirewallName
    egressRoutingTableName: egressRoutingTableName
  }
}

// Deploy and configure Azure Container Apps 
module containerAppsEnvModule 'modules/ca-environment.bicep' = {
  name: '${deployment().name}--containerAppsEnv'
  dependsOn: [
    vnetModule
  ]
  params: {
    location: location
    containerAppsEnvName: containerAppsEnvName
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    containerAppsSubnetProps: containerAppsSubnet
    containerAppsSubnetId: '${vnetModule.outputs.vnetId}/subnets/${containerAppsSubnet.name}'
    virtualNetworkApplianceIP: azureFirewallModule.outputs.virtualAppliancePublicIP
    egressRoutingTableName: egressRoutingTableName
    vnetName: vnetName
  }
}


// Deploy and configure Azure Application Gateway
module appGatewayModule 'modules/app-gateway.bicep' = {
  name: '${deployment().name}--appGateway'
  dependsOn: [
    azureFirewallModule
    containerAppsEnvModule
  ]
  params: {
    location: location
    containerAppsEnvName: containerAppsEnvName
    appGatewaySubnetId: '${vnetModule.outputs.vnetId}/subnets/${appGatewaySubnet.name}'
    appGatewayIPName: appGatewayIPName
    appGatewayName: appGatewayName
  }
}

// Configure Azure Private DNS settings for environment 
module privateDNSModule 'modules/private-dns.bicep' = {
  name: '${deployment().name}--private-dns'
  dependsOn:[
    containerAppsEnvModule
  ]
  params: {
    location: 'global'
    cappPrivateDnsZoneName: containerAppsEnvModule.outputs.defaultDomain
    staticIP: containerAppsEnvModule.outputs.staticIP
    vnetName: vnetName
  }
}

// Deploy a sample app 
module containerAppModule 'modules/containerapp.bicep' = {
  name: '${deployment().name}--album-api'
  dependsOn: [
    containerAppsEnvModule
  ]
  params: {
    location: location
    containerAppsEnvName: containerAppsEnvName
  }
}
