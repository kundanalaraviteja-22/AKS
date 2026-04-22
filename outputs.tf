# Outputs for AKS Cluster

output "resource_group_id" {
  description = "Resource group ID"
  value       = azurerm_resource_group.aks_rg.id
}

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.aks_rg.name
}

output "aks_cluster_id" {
  description = "AKS cluster ID"
  value       = azurerm_kubernetes_cluster.aks_cluster.id
}

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.aks_cluster.name
}

output "aks_cluster_fqdn" {
  description = "AKS cluster FQDN"
  value       = azurerm_kubernetes_cluster.aks_cluster.fqdn
}

output "aks_cluster_private_fqdn" {
  description = "AKS cluster private FQDN (if private cluster enabled)"
  value       = try(azurerm_kubernetes_cluster.aks_cluster.private_fqdn, "N/A")
}

output "aks_api_server_address" {
  description = "AKS API server address"
  value       = azurerm_kubernetes_cluster.aks_cluster.kube_config[0].host
  sensitive   = false
}

output "kube_config" {
  description = "Kubernetes cluster kubeconfig for accessing the cluster"
  value       = azurerm_kubernetes_cluster.aks_cluster.kube_config_raw
  sensitive   = true
}

output "kube_config_object" {
  description = "Raw kubeconfig as Terraform object"
  value       = azurerm_kubernetes_cluster.aks_cluster.kube_config
  sensitive   = true
}

output "client_certificate" {
  description = "Client certificate for Kubernetes API access"
  value       = azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Client key for Kubernetes API access"
  value       = azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_key
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate"
  value       = azurerm_kubernetes_cluster.aks_cluster.kube_config[0].cluster_ca_certificate
  sensitive   = false
}

output "aks_username" {
  description = "Admin username for AKS cluster"
  value       = azurerm_kubernetes_cluster.aks_cluster.kube_config[0].username
  sensitive   = false
}

output "aks_password" {
  description = "Admin password for AKS cluster (not recommended for production)"
  value       = azurerm_kubernetes_cluster.aks_cluster.kube_config[0].password
  sensitive   = true
}

output "kubelet_identity" {
  description = "Kubelet managed identity"
  value = {
    client_id  = local.kubelet_identity.client_id
    object_id  = local.kubelet_identity.object_id
    principal_id = local.kubelet_identity.principal_id
  }
  sensitive = false
}

output "aks_managed_identity_id" {
  description = "AKS managed identity ID"
  value       = azurerm_user_assigned_identity.aks_identity.id
}

output "virtual_network_id" {
  description = "Virtual network ID"
  value       = azurerm_virtual_network.aks_vnet.id
}

output "subnet_id" {
  description = "AKS subnet ID"
  value       = azurerm_subnet.aks_subnet.id
}

output "network_security_group_id" {
  description = "Network security group ID"
  value       = azurerm_network_security_group.aks_nsg.id
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  value       = var.enable_log_analytics ? azurerm_log_analytics_workspace.aks_workspace[0].id : null
}

output "log_analytics_workspace_name" {
  description = "Log Analytics workspace name"
  value       = var.enable_log_analytics ? azurerm_log_analytics_workspace.aks_workspace[0].name : null
}

output "container_registry_id" {
  description = "Container Registry ID"
  value       = var.enable_container_registry ? azurerm_container_registry.aks_acr[0].id : null
}

output "container_registry_url" {
  description = "Container Registry login server URL"
  value       = var.enable_container_registry ? azurerm_container_registry.aks_acr[0].login_server : null
}

output "container_registry_name" {
  description = "Container Registry name"
  value       = var.enable_container_registry ? azurerm_container_registry.aks_acr[0].name : null
}

# Useful commands output
output "configure_kubectl" {
  description = "Command to configure kubectl to access the cluster"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.aks_rg.name} --name ${azurerm_kubernetes_cluster.aks_cluster.name} --overwrite-existing"
}

output "get_kube_config" {
  description = "Command to get the kubeconfig file"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.aks_rg.name} --name ${azurerm_kubernetes_cluster.aks_cluster.name} --file kubeconfig.yaml"
}
