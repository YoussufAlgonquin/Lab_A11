terraform {
  required_version = "~> 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.96.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "githubactions" {
  name     = "hich0005-githubactions-rg"
  location = "canadacentral"
}

resource "azurerm_storage_account" "githubactions" {
  name                     = "hich0005githubactions"
  resource_group_name      = azurerm_resource_group.githubactions.name
  location                 = azurerm_resource_group.githubactions.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.githubactions.name
  container_access_type = "private"
}

output "resource_group_name" {
  value = azurerm_resource_group.githubactions.name
}

output "storage_account_name" {
  value = azurerm_storage_account.githubactions.name
}

output "container_name" {
  value = azurerm_storage_container.tfstate.name
}

output "arm_access_key" {
  value     = azurerm_storage_account.githubactions.primary_access_key
  sensitive = true
}
