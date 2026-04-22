# Log Analytics Workspace for AKS Monitoring
resource "azurerm_log_analytics_workspace" "aks_workspace" {
  count = var.enable_log_analytics ? 1 : 0

  name                = "law-aks-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  sku                 = var.log_analytics_workspace_sku
  retention_in_days   = var.environment == "prod" ? 90 : 30

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.project_name
      Purpose     = "AKS-Monitoring"
    }
  )
}

# Log Analytics Solution for Container Monitoring
resource "azurerm_log_analytics_solution" "container_insights" {
  count = var.enable_log_analytics ? 1 : 0

  solution_name         = "ContainerInsights"
  location              = azurerm_resource_group.aks_rg.location
  resource_group_name   = azurerm_resource_group.aks_rg.name
  workspace_resource_id = azurerm_log_analytics_workspace.aks_workspace[0].id
  workspace_name        = azurerm_log_analytics_workspace.aks_workspace[0].name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }

  depends_on = [azurerm_log_analytics_workspace.aks_workspace]
}

# Action Group for Alerts (optional)
resource "azurerm_monitor_action_group" "aks_alerts" {
  count = var.enable_log_analytics ? 1 : 0

  name                = "ag-aks-alerts-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.aks_rg.name
  short_name          = "aks-alert"

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.project_name
    }
  )
}

# Example Metric Alert for High CPU Usage
resource "azurerm_monitor_metric_alert" "aks_high_cpu" {
  count = var.enable_log_analytics ? 1 : 0

  name                = "alert-aks-high-cpu-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.aks_rg.name
  scopes              = [azurerm_kubernetes_cluster.aks_cluster.id]
  description         = "Alert when node CPU usage exceeds 80%"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_name      = "node_cpu_usage_percentage"
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.aks_alerts[0].id
  }

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.project_name
    }
  )
}

# Diagnostic Settings for AKS Cluster
resource "azurerm_monitor_diagnostic_setting" "aks_diagnostics" {
  count = var.enable_log_analytics ? 1 : 0

  name                       = "diag-aks-${var.project_name}-${var.environment}"
  target_resource_id         = azurerm_kubernetes_cluster.aks_cluster.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.aks_workspace[0].id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-scheduler"
  }

  enabled_log {
    category = "kube-audit"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
