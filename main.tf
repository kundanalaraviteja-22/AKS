# Resource Group
resource "azurerm_resource_group" "aks_rg" {
  name     = var.resource_group_name
  location = var.location

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.project_name
      Name        = var.resource_group_name
    }
  )
}

# Virtual Network
resource "azurerm_virtual_network" "aks_vnet" {
  name                = "vnet-${var.project_name}-${var.environment}"
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.project_name
    }
  )
}

# Subnet for AKS
resource "azurerm_subnet" "aks_subnet" {
  name                 = "subnet-aks-${var.project_name}-${var.environment}"
  resource_group_name  = azurerm_resource_group.aks_rg.name
  virtual_network_name = azurerm_virtual_network.aks_vnet.name
  address_prefixes     = var.subnet_address_prefix

  depends_on = [azurerm_virtual_network.aks_vnet]
}

# Network Security Group
resource "azurerm_network_security_group" "aks_nsg" {
  name                = "nsg-aks-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name

  security_rule {
    name                       = "AllowKubernetesAPI"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.project_name
    }
  )
}

# Associate NSG with Subnet
resource "azurerm_subnet_network_security_group_association" "aks_subnet_nsg" {
  subnet_id                 = azurerm_subnet.aks_subnet.id
  network_security_group_id = azurerm_network_security_group.aks_nsg.id
}

# User-Assigned Managed Identity for AKS
resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "uami-aks-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.project_name
    }
  )
}

# Role assignment for AKS to manage resources in the subnet
resource "azurerm_role_assignment" "aks_network_contributor" {
  scope              = azurerm_virtual_network.aks_vnet.id
  role_definition_name = "Network Contributor"
  principal_id       = azurerm_user_assigned_identity.aks_identity.principal_id
}

# Locals for tagging
locals {
  common_tags = merge(
    var.tags,
    var.aks_tags,
    {
      Environment = var.environment
      Project     = var.project_name
      ClusterName = var.cluster_name
    }
  )
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = var.cluster_name
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  dns_prefix          = "${var.project_name}-${var.environment}"

  kubernetes_version = var.kubernetes_version

  # Default Node Pool
  default_node_pool {
    name                = var.default_node_pool_name
    node_count         = var.node_count
    vm_size            = var.vm_size
    os_disk_size_gb    = var.os_disk_size_gb
    os_disk_type       = var.os_disk_type
    vnet_subnet_id     = azurerm_subnet.aks_subnet.id
    max_pods           = 110

    # Enable autoscaling
    enable_auto_scaling = true
    min_count           = var.min_node_count
    max_count           = var.max_node_count

    # Node labels and taints
    node_labels = {
      Environment = var.environment
      ManagedBy   = "Terraform"
    }

    node_taints = []

    tags = local.common_tags
  }

  # Network Configuration
  network_profile {
    network_plugin      = var.network_plugin
    network_policy      = var.network_policy
    service_cidr        = "10.0.0.0/16"
    dns_service_ip      = "10.0.0.10"
    docker_bridge_cidr  = "172.17.0.1/16"
    outbound_type       = var.outbound_type
    load_balancer_sku   = "standard"
  }

  # Identity Configuration
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_identity.id]
  }

  # RBAC Configuration
  role_based_access_control_enabled = var.enable_rbac

  # API Server Configuration
  api_server_access_profile {
    authorized_ip_ranges = var.enable_api_server_authorized_ip_ranges ? var.api_server_authorized_ip_ranges : []
  }

  # Enable monitoring
  oms_agent {
    enabled                    = var.enable_log_analytics
    log_analytics_workspace_id = var.enable_log_analytics ? azurerm_log_analytics_workspace.aks_workspace[0].id : null
  }

  # Azure Policy
  azure_policy_enabled = true

  # Auto-upgrade channel (stable for production)
  automatic_channel_upgrade = var.environment == "prod" ? "stable" : "patch"

  # Pod Security Policy
  pod_security_policy_enabled = var.enable_pod_security_policy

  # Maintenance Window (optional - configure based on maintenance schedule)
  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [0, 4]
    }

    not_allowed {
      start = "2024-12-25"
      end   = "2024-12-26"
    }
  }

  tags = local.common_tags

  depends_on = [
    azurerm_role_assignment.aks_network_contributor,
    azurerm_subnet_network_security_group_association.aks_subnet_nsg
  ]
}

# Kubelet Identity (for node authentication)
locals {
  kubelet_identity = azurerm_kubernetes_cluster.aks_cluster.kubelet_identity[0]
}

# Role assignment for kubelet identity
resource "azurerm_role_assignment" "aks_kubelet_managed_identity_operator" {
  scope              = azurerm_user_assigned_identity.aks_identity.id
  role_definition_name = "Managed Identity Operator"
  principal_id       = local.kubelet_identity.object_id
}

# Grant kubelet identity permissions for node operations
resource "azurerm_role_assignment" "aks_kubelet_vm_contributor" {
  scope              = azurerm_resource_group.aks_rg.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id       = local.kubelet_identity.object_id
}
