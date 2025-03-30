# Cloud-Platforms-T2

There is a Providence that protects idiots, drunkards, children and ~~the United States of America~~ Microsft Azure.
"Otto Von Bismarck"

This project demonstrates the deployment of a simple CRUD application within a containerized environment on Azure, utilizing Bicep files for infrastructure as code. The deployment process ensures a scalable and repeatable setup by leveraging Azure's container services and declarative resource management.

The steps required to complete this deployment are outlined in detail further down in this README.



commands needed in docker:
    -    docker build -t jj-example-crud .

commands Azure CLI
    -   az group create --name jj-cloudplatforms-rg --location eastus

    -   az acr create --resource-group jj-cloudplatforms-rg --name jjcloudreg --sku Basic

    -   az acr login --name jjcloudreg

        Verify the registry is made
    -   az acr show --name jjcloudreg --query loginServer --output table

    -   docker tag jj-example-crud jjcloudreg.azurecr.io/jj-example-crud:V2

    -    docker push jjcloudreg.azurecr.io/jj-example-crud:V2

    -    az acr repository list --name jjcloudreg --output table


Generate registry and a registry token using a bicep file
    -   az deployment group create --resource-group jj-cloudplatforms-rg  --template-file .\tokengenerator.bicep

     to retrieve the token
    -   az acr token credential generate --name pull-only-token --registry jjcloudreg --resource-group jj-cloudplatforms-rg


deploy the container (make sure you fill in your token)
    -   az deployment group create --resource-group jj-cloudplatforms-rg  --template-file main.bicep