@description('Name for the container group')
param name string = 'cloud-platforms-containergroup-jj'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Container image to deploy.')
param image string = 'jjcloudreg.azurecr.io/jj-example-crud:V2'

@description('Port to open on the container and the public IP address.')
param port int = 80

@description('The number of CPU cores to allocate to the container.')
param cpuCores int = 1

@description('The amount of memory to allocate to the container in gigabytes.')
param memoryInGb int = 1

@description('The behavior of Azure runtime if container has stopped.')
@allowed([
  'Always'
  'Never'
  'OnFailure'
])
param restartPolicy string = 'Always'

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: name
  location: location
  properties: {
    containers: [
      {
        name: name
        properties: {
          image: image
          ports: [
            {
              port: port
              protocol: 'TCP'
            }
          ]
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGb
            }
          }
        }
      }
    ]
    osType: 'Linux'
    restartPolicy: restartPolicy
    ipAddress: {
      type: 'Public'
      ports: [
        {
          port: port
          protocol: 'TCP'
        }
      ]
    }
    imageRegistryCredentials: [
      {
        server: 'jjcloudreg.azurecr.io'
        username: 'pull-only-token'
        password: 'SkQHEu82LHhKTWPpUpHEGzS1Ulf+LUSD8YU2QOFvpZ+ACRAtfFgt'
      }
    ]
  }
}

output name string = containerGroup.name
output resourceGroupName string = resourceGroup().name
output resourceId string = containerGroup.id
output location string = location
