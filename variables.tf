variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,90}$", var.resource_group_name))
    error_message = "Resource group name must be between 1-90 characters and contain only alphanumeric characters, hyphens, and underscores."
  }
}

variable "location" {
  description = "Azure region for resources (e.g., eastus, westus2, eastus2)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]+$", var.location))
    error_message = "Location must be a valid Azure region."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Project name to be used as part of resource naming"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{1,10}$", var.project_name))
    error_message = "Project name must be 1-10 lowercase alphanumeric characters."
  }
}

variable "cluster_name" {
  description = "AKS cluster name"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{1,63}$", var.cluster_name))
    error_message = "Cluster name must be 1-63 lowercase alphanumeric characters."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for AKS cluster"
  type        = string
  default     = "1.30"
}

variable "default_node_pool_name" {
  description = "Name of the default node pool"
  type        = string
  default     = "default"
  validation {
    condition     = can(regex("^[a-z0-9]{1,12}$", var.default_node_pool_name))
    error_message = "Node pool name must be 1-12 lowercase alphanumeric characters."
  }
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 3
  validation {
    condition     = var.node_count >= 1 && var.node_count <= 100
    error_message = "Node count must be between 1 and 100."
  }
}

variable "min_node_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 1
  validation {
    condition     = var.min_node_count >= 1 && var.min_node_count <= var.node_count
    error_message = "Minimum node count must be >= 1 and <= node_count."
  }
}

variable "max_node_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 5
  validation {
    condition     = var.max_node_count >= var.node_count
    error_message = "Maximum node count must be >= node_count."
  }
}

variable "vm_size" {
  description = "VM size for nodes (e.g., Standard_D2s_v3, Standard_D4s_v3)"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "network_plugin" {
  description = "Network plugin to use for networking (azure or kubenet)"
  type        = string
  default     = "azure"
  validation {
    condition     = contains(["azure", "kubenet"], var.network_plugin)
    error_message = "Network plugin must be either 'azure' or 'kubenet'."
  }
}

variable "network_policy" {
  description = "Network policy to use (azure or calico)"
  type        = string
  default     = "azure"
  validation {
    condition     = contains(["azure", "calico"], var.network_policy)
    error_message = "Network policy must be either 'azure' or 'calico'."
  }
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "subnet_address_prefix" {
  description = "Address prefix for the AKS subnet"
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "enable_log_analytics" {
  description = "Enable Log Analytics monitoring for the AKS cluster"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_sku" {
  description = "SKU of the Log Analytics workspace"
  type        = string
  default     = "PerGB2018"
}

variable "enable_container_registry" {
  description = "Create and integrate Azure Container Registry with AKS"
  type        = bool
  default     = true
}

variable "acr_sku" {
  description = "SKU of the Azure Container Registry"
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "ACR SKU must be one of: Basic, Standard, Premium."
  }
}

variable "enable_api_server_authorized_ip_ranges" {
  description = "Enable API server authorized IP ranges for security"
  type        = bool
  default     = true
}

variable "api_server_authorized_ip_ranges" {
  description = "Authorized IP ranges for API server access (CIDR format)"
  type        = list(string)
  default     = []
}

variable "enable_rbac" {
  description = "Enable RBAC for the cluster"
  type        = bool
  default     = true
}

variable "enable_pod_security_policy" {
  description = "Enable Pod Security Policy"
  type        = bool
  default     = false
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB for nodes"
  type        = number
  default     = 128
}

variable "os_disk_type" {
  description = "OS disk type for nodes"
  type        = string
  default     = "Managed"
}

variable "outbound_type" {
  description = "Outbound type for cluster (loadBalancer, userDefinedRouting, managedNATGateway)"
  type        = string
  default     = "loadBalancer"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
  }
}

variable "aks_tags" {
  description = "Additional tags specific to AKS resources"
  type        = map(string)
  default     = {}
}
