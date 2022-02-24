terraform {
  required_providers {
    azurerm = "~> 2.0"
    azuread = "~> 2.0"
  }
}

provider "azurerm" {
  features {}
}

data "azuread_client_config" "current" {}

resource "azurerm_resource_group" "default" {
  name     = "rg-terraform-test"
  location = "westus2"
}

resource "azurerm_application_insights" "default" {
  name                = "appi-terraform-test"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
  application_type    = "web"
}

resource "azurerm_app_service_plan" "default" {
  name                = "plan-terraform-test"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location

  sku {
    tier = "Standard"
    size = "S1"
  }
}