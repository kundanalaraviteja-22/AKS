# Azure Kubernetes Service (AKS) Terraform Configuration

This Terraform configuration provides a production-ready deployment of Azure Kubernetes Service (AKS) with comprehensive security, monitoring, and networking configurations.

## 📋 Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Directory Structure](#directory-structure)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Post-Deployment](#post-deployment)
- [Security Considerations](#security-considerations)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## ✨ Features

- **High-Availability AKS Cluster**: Multi-node cluster with auto-scaling capabilities
- **Network Security**: 
  - Virtual Network with dedicated subnets
  - Network Security Groups (NSGs) with security rules
  - Azure Network Policy for pod-to-pod communication control
  - API server authorized IP ranges
- **Identity & Access**:
  - System-managed identity with User-Assigned Identity
  - RBAC enabled by default
  - Role-based access control for managed identities
- **Monitoring & Logging**:
  - Azure Log Analytics integration
  - Container Insights for cluster monitoring
  - Azure Policy enabled
  - Diagnostic settings for API server logs
- **Container Registry**:
  - Azure Container Registry (ACR) integration
  - Secure pull/push capabilities via managed identities
  - Optional private endpoint support
- **Best Practices**:
  - Proper naming conventions following Azure guidelines
  - Comprehensive tagging strategy
  - Auto-upgrade configuration per environment
  - Maintenance windows defined
  - Security hardening with NSG rules

## 📋 Prerequisites

### Required Tools

1. **Terraform** (v1.3+): [Installation Guide](https://developer.hashicorp.com/terraform/downloads)
   ```bash
   winget install Hashicorp.Terraform
   ```

2. **Azure CLI** (v2.50+): [Installation Guide](https://learn.microsoft.com/cli/azure/install-azure-cli-windows)
   ```bash
   winget install Microsoft.AzureCLI
   ```

3. **kubectl** (v1.28+): [Installation Guide](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/)
   ```bash
   winget install Kubernetes.kubectl
   ```

### Azure Requirements

- Active Azure subscription
- Appropriate RBAC permissions (Contributor or Owner role)
- Sufficient quota for resources in target region

### Authenticate with Azure

```bash
# Login to Azure
az login

# If you have multiple subscriptions, set the target subscription
az account set --subscription <subscription-id>

# Verify authentication
az account show
```

## 📁 Directory Structure

```
.
├── provider.tf                 # Terraform provider and version requirements
├── main.tf                     # AKS cluster, VNet, subnets, NSG, identities
├── variables.tf                # All variable definitions with validation
├── log_analytics.tf            # Log Analytics workspace and monitoring
├── container_registry.tf       # Azure Container Registry configuration
├── outputs.tf                  # Output values (kube_config, endpoints, etc.)
├── terraform.tfvars.example    # Example variable values (copy to terraform.tfvars)
├── .gitignore                  # Git ignore patterns for Terraform
├── README.md                   # This file
└── .terraform/                 # (Generated) Terraform working directory
```

## 🚀 Quick Start

### 1. Clone and Setup

```bash
# Navigate to the directory
cd d:\AKS_Terraform

# Copy the example variables file
copy terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your configuration
# - Set resource_group_name, location, cluster_name, etc.
# - Adjust node_count, vm_size based on your needs
# - Configure API server authorized IP ranges if required
```

### 2. Initialize Terraform

```bash
# Initialize the Terraform working directory
terraform init

# Verify initialization
terraform validate
```

### 3. Review and Deploy

```bash
# Generate and review the execution plan
terraform plan -out=tfplan

# Apply the configuration (requires approval if not using -auto-approve)
terraform apply tfplan

# Save outputs to a file
terraform output -json > outputs.json
```

### 4. Configure kubectl

```bash
# Get the kubeconfig credentials
az aks get-credentials --resource-group <resource-group-name> --name <cluster-name>

# Verify cluster access
kubectl get nodes
kubectl get pods --all-namespaces
```

## ⚙️ Configuration

### Key Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `resource_group_name` | Azure Resource Group name | - | Yes |
| `location` | Azure region (e.g., eastus, westus2) | - | Yes |
| `cluster_name` | AKS cluster name | - | Yes |
| `environment` | Environment type (dev, staging, prod) | - | Yes |
| `project_name` | Project name for naming resources | - | Yes |
| `node_count` | Number of nodes in default pool | 3 | No |
| `min_node_count` | Minimum nodes for autoscaling | 1 | No |
| `max_node_count` | Maximum nodes for autoscaling | 5 | No |
| `vm_size` | Virtual machine size | Standard_D2s_v3 | No |
| `kubernetes_version` | Kubernetes version | 1.30 | No |
| `network_plugin` | CNI plugin (azure or kubenet) | azure | No |
| `enable_log_analytics` | Enable monitoring | true | No |
| `enable_container_registry` | Enable ACR | true | No |
| `enable_rbac` | Enable RBAC | true | No |

### Environment-Specific Configuration

#### Development Environment
```hcl
environment         = "dev"
node_count          = 1
min_node_count      = 1
max_node_count      = 3
vm_size             = "Standard_D2s_v3"
log_analytics_workspace_sku = "PerGB2018"
automatic_channel_upgrade   = "patch"
```

#### Production Environment
```hcl
environment         = "prod"
node_count          = 3
min_node_count      = 2
max_node_count      = 10
vm_size             = "Standard_D4s_v3"
enable_api_server_authorized_ip_ranges = true
automatic_channel_upgrade   = "stable"
```

## 📝 Deployment

### Full Deployment Workflow

```bash
# 1. Initialize
terraform init

# 2. Validate configuration
terraform validate

# 3. Plan and review
terraform plan -out=tfplan

# 4. Apply configuration
terraform apply tfplan

# 5. Get kubeconfig
az aks get-credentials --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name) --overwrite-existing

# 6. Verify cluster
kubectl cluster-info
kubectl get nodes
```

### Using Auto-Approve (Not Recommended for Production)

```bash
terraform apply -auto-approve -var-file="terraform.tfvars"
```

### Validate Deployment

```bash
# Check cluster status
az aks show --resource-group <rg-name> --name <cluster-name> -o jsonc

# Verify nodes
kubectl get nodes -o wide

# Check system namespaces
kubectl get pods -n kube-system

# Test networking
kubectl run test-pod --image=mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11
kubectl get pods

# Verify ACR integration
kubectl get secret azure-registry --namespace default -o yaml 2>/dev/null || echo "No ACR secret"
```

## 🔧 Post-Deployment

### Configure Azure Policy

Azure Policy is enabled by default. To manage policies:

```bash
# View assigned policies
az aks show --query "azure_policy_status" -g <rg-name> -n <cluster-name>

# Add policies via Azure Portal or Azure Policy Manager
```

### Setup Container Registry

If ACR was deployed, configure access:

```bash
# Login to ACR
az acr login --name $(terraform output -raw container_registry_name)

# Push a sample image
docker tag myimage:latest $(terraform output -raw container_registry_url)/myimage:latest
docker push $(terraform output -raw container_registry_url)/myimage:latest
```

### Install Ingress Controller

```bash
# Using Helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

### Setup Persistent Storage

```bash
# Create a storage class
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-premium
provisioner: disk.csi.azure.com
parameters:
  skuname: Premium_LRS
  replication-type: None
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
EOF
```

## 🔒 Security Considerations

### Network Security

1. **NSG Rules**: Default NSG allows only Kubernetes API (port 443) inbound
2. **Network Policy**: Azure Network Policy restricts pod-to-pod communication
3. **API Server**: Authorized IP ranges restrict API access (configure `api_server_authorized_ip_ranges`)

### Identity & Access

1. **RBAC**: Enabled by default for fine-grained access control
2. **Managed Identity**: Uses system-assigned identity for secure credential management
3. **Role Assignments**: Minimal required permissions granted to identities

### Best Practices

```bash
# Enable Pod Security Standards
kubectl label namespace default pod-security.kubernetes.io/enforce=baseline

# Setup Network Policies
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# Enable audit logging (already configured in diagnostics)
az aks show --query "azure_policy_status" -g <rg-name> -n <cluster-name>
```

### Recommended Additions

- **Secrets Management**: Integrate with Azure Key Vault
- **Private AKS Cluster**: Configure private endpoint for API server
- **Firewall**: Deploy Azure Firewall for egress traffic control
- **DDoS Protection**: Enable Azure DDoS Protection Standard
- **SSL/TLS**: Configure HTTPS for ingress controllers

## 📊 Monitoring

### View Cluster Metrics

Access Container Insights in Azure Portal:

```bash
# Get Log Analytics workspace name
terraform output log_analytics_workspace_name

# View cluster metrics URL
echo "https://portal.azure.com/#@microsoft.onmicrosoft.com/resource$(terraform output -raw aks_cluster_id)/insights"
```

### Common Queries

```bash
# View container metrics
az monitor metrics list --resource $(terraform output -raw aks_cluster_id) \
  --metric "node_cpu_usage_percentage" --start-time "2026-04-20" --interval PT1H

# View logs
az monitor log-analytics query --workspace $(terraform output -raw log_analytics_workspace_id) \
  --analytics-query "ContainerLog | limit 10"
```

### Alerts

Metric alerts are configured in `log_analytics.tf`. To add more:

```bash
# Create alert for node memory
az monitor metrics alert create \
  --name alert-high-memory \
  --resource-group $(terraform output -raw resource_group_name) \
  --scopes $(terraform output -raw aks_cluster_id) \
  --condition "avg node_memory_usage_percentage > 85" \
  --description "Alert when memory usage exceeds 85%"
```

## 🔍 Troubleshooting

### Common Issues

#### 1. Terraform Validation Fails
```bash
terraform validate
# Check error messages and variable values in terraform.tfvars
```

#### 2. Resource Group Already Exists
```bash
# Check existing resources
az group show --name <resource-group-name>
# Either use different name or use existing group (modify main.tf)
```

#### 3. Insufficient Quota
```bash
# Check quotas
az vm list-usage --location <region> --query "[?name.value=='Compute'].{name:name.value, current:currentValue, limit:limit}"
```

#### 4. kubeconfig Access Issues
```bash
# Regenerate credentials
az aks get-credentials --resource-group <rg-name> --name <cluster-name> --overwrite-existing --file kubeconfig.yaml

# Verify connectivity
kubectl cluster-info --kubeconfig kubeconfig.yaml
```

#### 5. Cluster Upgrade Issues
```bash
# Check upgrade status
az aks show --resource-group <rg-name> --name <cluster-name> \
  --query "kubernetesVersion"

# Manual upgrade
az aks upgrade --resource-group <rg-name> --name <cluster-name> \
  --kubernetes-version 1.30
```

## 🧹 Cleanup

### Destroy Resources

```bash
# Plan destruction
terraform plan -destroy

# Destroy all resources (requires confirmation)
terraform destroy

# Destroy without confirmation (use with caution)
terraform destroy -auto-approve

# Clean up local state
rm -r .terraform
rm terraform.tfstate*
rm .terraform.lock.hcl
```

### Selective Cleanup

```bash
# Destroy only ACR
terraform destroy -target azurerm_container_registry.aks_acr -auto-approve

# Destroy only Log Analytics
terraform destroy -target azurerm_log_analytics_workspace.aks_workspace -auto-approve
```

## 📚 Additional Resources

- [AKS Best Practices](https://learn.microsoft.com/en-us/azure/aks/best-practices)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Azure Naming Conventions](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules)
- [Azure Well-Architected Framework](https://learn.microsoft.com/en-us/azure/architecture/framework/)

## 📄 License

This configuration is provided as-is for use with Azure deployments.

## ❓ Support

For issues and questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review [AKS documentation](https://learn.microsoft.com/en-us/azure/aks/)
3. Check [Terraform logs](https://www.terraform.io/docs/commands/environment-variables.html#tf_log) with `export TF_LOG=DEBUG`
4. Review Azure CLI logs with `az --debug`

---

**Last Updated**: April 22, 2026  
**Terraform Version**: >= 1.3  
**Azure Provider Version**: >= 4.2
