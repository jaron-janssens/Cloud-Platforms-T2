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

@description('Name of the Virtual Network.')
param vnetName string = 'jj-cloud-platforms-vnet'

@description('Address prefix for the Virtual Network')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Name of the Application Gateway.')
param appGatewayName string = 'jj-cloud-platforms-appgw'

@description('SKU Name for Application Gateway')
param appGatewaySku string = 'Standard_v2'

@description('SKU Tier for Application Gateway')
param appGatewayTier string = 'Standard_v2'

/*
  Subnet configuration:
  - `containerSubnetName`: Subnet for the container group.
  - `appGatewaySubnetName`: Subnet for the Application Gateway.
*/
var containerSubnetName = 'container-subnet'
var containerSubnetPrefix = '10.0.1.0/24'
var appGatewaySubnetName = 'appgw-subnet'
var appGatewaySubnetPrefix = '10.0.0.0/24'

/*
  Create a Public IP for the Application Gateway:
  - This public IP is used to make the application accessible over the internet.
*/
resource publicIP 'Microsoft.Network/publicIPAddresses@2023-02-01' = {
  name: '${appGatewayName}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${name}-dns')
    }
  }
}

/*
  Create a Virtual Network with subnets:
  - `appGatewaySubnet`: Subnet for the Application Gateway.
  - `containerSubnet`: Subnet for the container group, delegated to Azure Container Instances.
*/
resource vnet 'Microsoft.Network/virtualNetworks@2023-02-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: appGatewaySubnetName
        properties: {
          addressPrefix: appGatewaySubnetPrefix
        }
      }
      {
        name: containerSubnetName
        properties: {
          addressPrefix: containerSubnetPrefix
          delegations: [
            {
              name: 'DelegationService'
              properties: {
                serviceName: 'Microsoft.ContainerInstance/containerGroups'
              }
            }
          ]
        }
      }
    ]
  }
}

/*
  Reference the Application Gateway subnet:
  - This allows the Application Gateway to use the `appgw-subnet`.
*/
resource appGatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2023-02-01' existing = {
  name: '${vnetName}/${appGatewaySubnetName}'
  dependsOn: [
    vnet
  ]
}

/*
  Reference the Container Group subnet:
  - This allows the container group to use the `container-subnet`.
*/
resource containerSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-02-01' existing = {
  name: '${vnetName}/${containerSubnetName}'
  dependsOn: [
    vnet
  ]
}

/*
  Create a Network Security Group (NSG) for the container subnet:
  - Allows HTTP traffic on port 80.
  - Denies all other inbound traffic.
*/
resource containerSubnetNSG 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: '${containerSubnetName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

/*
  Associate the NSG with the container subnet:
  - Ensures the NSG rules are applied to the `container-subnet`.
*/
resource containerSubnetWithNSG 'Microsoft.Network/virtualNetworks/subnets@2023-02-01' = {
  name: '${vnetName}/${containerSubnetName}'
  properties: {
    addressPrefix: containerSubnetPrefix
    networkSecurityGroup: {
      id: containerSubnetNSG.id
    }
    delegations: [
      {
        name: 'DelegationService'
        properties: {
          serviceName: 'Microsoft.ContainerInstance/containerGroups'
        }
      }
    ]
  }
  dependsOn: [
    containerSubnetNSG
  ]
}

/*
  Create a Network Profile for the container group:
  - Configures the container group to use the `container-subnet`.
*/
resource networkProfile 'Microsoft.Network/networkProfiles@2023-02-01' = {
  name: '${name}-networkprofile'
  location: location
  properties: {
    containerNetworkInterfaceConfigurations: [
      {
        name: '${name}-cnic'
        properties: {
          ipConfigurations: [
            {
              name: '${name}-ipconfig'
              properties: {
                subnet: {
                  id: containerSubnet.id
                }
              }
            }
          ]
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}

/*
  Create the Container Group:
  - Runs the containerized application.
  - Configured with private networking and diagnostics.
*/
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
    subnetIds: [
      {
        id: containerSubnet.id
      }
    ]
    imageRegistryCredentials: [
      {
        server: 'jjcloudreg.azurecr.io'
        username: 'pull-only-token'
        password: 'SkQHEu82LHhKTWPpUpHEGzS1Ulf+LUSD8YU2QOFvpZ+ACRAtfFgt'
      }
    ]
  }
  dependsOn: [
    networkProfile
  ]
}

/*
  Create the Application Gateway:
  - Routes HTTP traffic to the container group.
  - Configured with a public IP and backend pool.
*/
resource applicationGateway 'Microsoft.Network/applicationGateways@2023-02-01' = {
  name: appGatewayName
  location: location
  properties: {
    sku: {
      name: appGatewaySku
      tier: appGatewayTier
      capacity: 2
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: appGatewaySubnet.id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'containerBackendPool'
        properties: {
          backendAddresses: [
            {
              ipAddress: reference(containerGroup.id).ipAddress.ip
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'containerHttpSettings'
        properties: {
          port: port
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
        }
      }
    ]
    httpListeners: [
      {
        name: 'httpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'port_80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'routingRule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'httpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'containerBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'containerHttpSettings')
          }
        }
      }
    ]
  }
  dependsOn: [
    containerGroup
  ]
}

/*
  Outputs:
  - Provide key information about the deployed resources.
*/
output containerGroupName string = containerGroup.name
output containerGroupIP string = reference(containerGroup.id).ipAddress.ip
output resourceGroupName string = resourceGroup().name
output applicationGatewayName string = applicationGateway.name
output applicationGatewayPublicIP string = publicIP.properties.ipAddress
output applicationGatewayFQDN string = publicIP.properties.dnsSettings.fqdn
