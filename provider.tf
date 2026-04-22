terraform {
  required_version = ">= 1.3"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.2"
    }
  }

  # Uncomment and configure for remote state management
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "stgterraformstate"
  #   container_name       = "tfstate"
  #   key                  = "aks/terraform.tfstate"
  # }
}

provider "azurerm" {
  features {
    virtual_machine {
      delete_os_disk_on_deletion            = true
      graceful_shutdown                     = false
      skip_shutdown_and_force_delete        = false
    }
  }

  skip_provider_registration = false
}
