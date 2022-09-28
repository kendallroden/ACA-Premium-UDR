param containerAppName string = 'testapp'
param containerAppsEnvName string 
param location string = 'northcentralusstage'

resource environment 'Microsoft.App/managedEnvironments@2022-06-01-preview' existing = {
  name: containerAppsEnvName
}

resource containerApp 'Microsoft.App/containerapps@2022-06-01-preview' = {
  name: containerAppName
  location: location
  identity: {
    type: 'None'
  }
  properties: {
    workloadProfileType: 'GP1'
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
        transport: 'Auto'
        allowInsecure: true
      }
    }
    template: {
      containers: [
        {
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          name: 'premiumexample'
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}
