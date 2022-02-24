resource "azuread_application" "frontend" {
  display_name = "Frontend example"
  owners       = [data.azuread_client_config.current.object_id]

  required_resource_access {
    resource_app_id = azuread_application.backend.application_id

    resource_access {
      id   = azuread_application.backend.oauth2_permission_scope_ids["user_impersonation"]
      type = "Scope"
    }
  }

  web {
    redirect_uris = ["https://func-terraform-frontend.azurewebsites.net/.auth/login/aad/callback"]

    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = true
    }
  }
}

resource "azuread_application_password" "frontend" {
  application_object_id = azuread_application.frontend.object_id
  end_date_relative     = "4320h"
}

resource "azurerm_storage_account" "frontend" {
  name                     = "stterraformtestfrontend"
  resource_group_name      = azurerm_resource_group.default.name
  location                 = azurerm_resource_group.default.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_function_app" "frontend" {
  name                       = "func-terraform-frontend"
  resource_group_name        = azurerm_resource_group.default.name
  location                   = azurerm_resource_group.default.location
  app_service_plan_id        = azurerm_app_service_plan.default.id
  storage_account_name       = azurerm_storage_account.frontend.name
  storage_account_access_key = azurerm_storage_account.frontend.primary_access_key

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

    additional_login_params = {
      "scope" = "openid profile email offline_access api://terraform-backend/user_impersonation"
    }

    active_directory {
      client_id     = azuread_application.frontend.application_id
      client_secret = azuread_application_password.frontend.value
    }
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.default.instrumentation_key
    "FUNCTIONS_WORKER_RUNTIME"       = "dotnet"
  }
}
