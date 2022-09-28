param location string 
param vnetName string 
param vnetPrefix string 

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetPrefix
      ]
    }
  }
}

output vnetId string = vnet.id
