resource "random_uuid" "user_impersonation" {}

resource "azuread_application" "backend" {
  display_name    = "Backend example"
  identifier_uris = ["api://terraform-backend"]
  owners          = [data.azuread_client_config.current.object_id]

  api {
    requested_access_token_version = 2

    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to access Backend example on behalf of the signed-in user."
      admin_consent_display_name = "Access Backend example"
      enabled                    = true
      id                         = random_uuid.user_impersonation.result
      type                       = "User"
      user_consent_description   = "Allow the application to access Backend example on your behalf."
      user_consent_display_name  = "Access Backend example"
      value                      = "user_impersonation"
    }
  }

  web {
    redirect_uris = ["https://func-terraform-backend.azurewebsites.net/.auth/login/aad/callback"]

    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = true
    }
  }
}

resource "azuread_service_principal" "backend" {
  application_id = azuread_application.backend.application_id
}

resource "azuread_application_password" "backend" {
  application_object_id = azuread_application.backend.object_id
  end_date_relative     = "4320h"
}

resource "azurerm_storage_account" "backend" {
  name                     = "stterraformtestbackend"
  resource_group_name      = azurerm_resource_group.default.name
  location                 = azurerm_resource_group.default.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_function_app" "backend" {
  name                       = "func-terraform-backend"
  resource_group_name        = azurerm_resource_group.default.name
  location                   = azurerm_resource_group.default.location
  app_service_plan_id        = azurerm_app_service_plan.default.id
  storage_account_name       = azurerm_storage_account.backend.name
  storage_account_access_key = azurerm_storage_account.backend.primary_access_key

  version                = "~4"
  enable_builtin_logging = false
  https_only             = true

  site_config {
    always_on                = true
    http2_enabled            = true
    dotnet_framework_version = "v6.0"
  }

  auth_settings {
    enabled                       = true
    token_store_enabled           = true
    default_provider              = "AzureActiveDirectory"
    unauthenticated_client_action = "RedirectToLoginPage"
    issuer                        = "https://login.microsoftonline.com/${data.azuread_client_config.current.tenant_id}/v2.0"

    active_directory {
      client_id     = azuread_application.backend.application_id
      client_secret = azuread_application_password.backend.value
    }
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.default.instrumentation_key
    "FUNCTIONS_WORKER_RUNTIME"       = "dotnet"
  }
}