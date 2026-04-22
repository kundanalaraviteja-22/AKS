# Azure Container Registry
resource "azurerm_container_registry" "aks_acr" {
  count = var.enable_container_registry ? 1 : 0

  name                = "acr${replace(var.project_name, "-", "")}${var.environment}"
  resource_group_name = azurerm_resource_group.aks_rg.name
  location            = azurerm_resource_group.aks_rg.location
  sku                 = var.acr_sku
  admin_enabled       = false

  # Network rules for security
  public_network_access_enabled = true

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.project_name
      Purpose     = "Container-Registry"
    }
  )
}

# ACR to AKS integration - Grant AKS access to pull images from ACR
resource "azurerm_role_assignment" "aks_pull_from_acr" {
  count = var.enable_container_registry ? 1 : 0

  scope              = azurerm_container_registry.aks_acr[0].id
  role_definition_name = "AcrPull"
  principal_id       = local.kubelet_identity.object_id
}

# ACR to AKS integration - Grant AKS push capability (optional for CI/CD)
resource "azurerm_role_assignment" "aks_push_to_acr" {
  count = var.enable_container_registry ? 1 : 0

  scope              = azurerm_container_registry.aks_acr[0].id
  role_definition_name = "AcrPush"
  principal_id       = azurerm_user_assigned_identity.aks_identity.principal_id
}

# Private Endpoint for ACR (optional - for enhanced security)
# Uncomment to enable private endpoint connectivity
# resource "azurerm_private_endpoint" "acr_private_endpoint" {
#   count = var.enable_container_registry ? 1 : 0
#
#   name                = "pe-acr-${var.project_name}-${var.environment}"
#   location            = azurerm_resource_group.aks_rg.location
#   resource_group_name = azurerm_resource_group.aks_rg.name
#   subnet_id           = azurerm_subnet.aks_subnet.id
#
#   private_service_connection {
#     name                           = "psc-acr-${var.project_name}"
#     is_manual_connection           = false
#     private_connection_resource_id = azurerm_container_registry.aks_acr[0].id
#     subresource_names              = ["registry"]
#   }
#
#   tags = merge(
#     var.tags,
#     {
#       Environment = var.environment
#       Project     = var.project_name
#     }
#   )
# }

# Network Rule for ACR (restrict to AKS subnet if using private endpoint)
# resource "azurerm_container_registry_network_rule_set" "acr_network_rules" {
#   count = var.enable_container_registry ? 1 : 0
#
#   container_registry_name = azurerm_container_registry.aks_acr[0].name
#   resource_group_name     = azurerm_resource_group.aks_rg.name
#
#   default_action = "Allow"
#
#   virtual_network {
#     action            = "Allow"
#     subnet_id         = azurerm_subnet.aks_subnet.id
#   }
#
#   depends_on = [azurerm_container_registry.aks_acr]
# }
