#!/bin/bash

initial_setup() {
    read -p "Do you have az cli installed(Y/N): " azure_installed
    if [[ "$azure_installed" == "Y" || "$azure_installed" == "y" ]]; then
      echo "You have azure cli installed, carry on"
      echo " -------------------------"
    else
      curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    fi
}

auth_function() {
    read -p "Authenticate to Azure(Y/N) : " authenticate_answer
    if [[ "$authenticate_answer" == "y" || "$authenticate_answer" == "Y" ]]; then
      az login --use-device-code
    else
      echo "You are skipping authentication"
    fi
}

create_azure_resource_group() {
    read -p "Enter a name for your resource group: " resource_group
    read -p "Enter the location you want to create the group: " location
    while true; do
      if [[ $(az group exists --name $resource_group) ]]; then
        echo "Resource group already exists"
        break
      else
        echo "Creating resource group: $resource_group"
        if [[ $(az group create --name $resource_group --location $location) ]]; then
          echo "Resource group created successfully"
          break
        else
          echo "Resource group creation failed; Try again"
          read -p "Enter a new name for your resource group or press Enter to retry: " new_resource_group
          if [[ -n $new_resource_group ]]; then
            resource_group=$new_resource_group
          fi
        fi          
      fi
    done
}

create_storage() {
    read -p "Name your storage account: " storage_account
    subscription=$(az account show --query id --output tsv)
    while true; do
      name_available=$(az storage account check-name --name $storage_account --subscription $subscription --query nameAvailable --output tsv)
      if [[ $name_available == "false" ]]; then
        echo "Storage account already exists"
        break
      else
        echo "Creating storage account: $storage_account"
        if [[ $(az storage account create --name $storage_account --resource-group $resource_group --location $location --encryption-services blob --sku Standard_LRS --subscription $subscription) ]]; then
          echo "Storage account created successfully"
          break
        else
          echo "Storage account creation failed; Try again"
          read -p "Enter a new name for your storage account or press Enter to retry: " new_storage_account
          if [[ -n $new_storage_account ]]; then
            storage_account=$new_storage_account
          fi
        fi
      fi
    done
}

create_container() {
  read -p "Enter the name of the container you want to create: " container_name
  while true; do
    container_exists=$(az storage container exists --name $container_name --account-name $storage_account --auth-mode login --output tsv)
    echo $container_exists
    if [[ $container_exists == "True" || $container_exists == "true" ]]; then
      echo "Container already exists"
      break
    else
      echo "Creating Container: $container_name"
      if az storage container create --name $container_name --auth-mode login --account-name $storage_account --subscription $subscription --fail-on-exist;then
        echo " container created successfully"
        break
      else
        echo "Container creation failed; Try again"
        read -p "Enter a new name for your container or press Enter to retry: " new_container_name
        if [[ -n $new_container_name ]]; then
          container_name=$new_container_name
        fi
      fi
    fi
  done
}

upload_file() {
    file=$1
    while true; do
      if [ -f $file ]; then
        echo "Uploading file: $file"
        if pv "$file" | az storage blob upload --account-name $storage_account --container-name $container_name --name $file --subscription $subscription --data -; then
          echo "File uploaded successfully"
          break
        else
          echo "File upload failed; try again"
          read -p "Enter the file path or press Enter to retry: " new_file
          if [[ -n $new_file ]]; then
            file=$new_file
          fi
        fi
      else
        echo "File does not exist"
        exit 1
      fi
    done
}


initial_setup
auth_function
create_azure_resource_group
create_storage
create_container
upload_file $1