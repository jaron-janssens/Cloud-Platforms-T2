@description('The name of the resource group.')
param resourceGroupName string = 'jj-cloudplatforms-rg'

@description('The location for the resources.')
param location string = 'eastus'

@description('The name of the Azure Container Registry.')
param acrName string = 'jjcloudreg'

@description('The name of the repository in the ACR.')
param repositoryName string = 'jj-example-crud'

@description('The name of the scope map for pull-only access.')
param scopeMapName string = 'pull-only-scope'

@description('The name of the token for pull-only access.')
param tokenName string = 'pull-only-token'

@description('The description for the scope map.')
param scopeMapDescription string = 'scopemap for pull-only-access'

// Create the Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

// Create a scope map for pull-only access
resource acrScopeMap 'Microsoft.ContainerRegistry/registries/scopeMaps@2023-01-01-preview' = {
  name: scopeMapName
  parent: acr
  properties: {
    actions: [
      'repositories/${repositoryName}/content/read'
    ]
    description: scopeMapDescription
  }
}

// Create a token associated with the scope map
resource acrToken 'Microsoft.ContainerRegistry/registries/tokens@2023-01-01-preview' = {
  name: tokenName
  parent: acr
  properties: {
    scopeMapId: acrScopeMap.id
    status: 'enabled'
  }
}

