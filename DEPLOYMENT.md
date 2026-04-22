# AKS Deployment Guide

This guide provides step-by-step instructions for deploying the AKS cluster using Terraform.

## Prerequisites Verification

Before starting, verify all prerequisites are installed:

```powershell
# Check Terraform
terraform version

# Check Azure CLI
az version

# Check kubectl
kubectl version --client

# Verify Azure login
az account show
```

## Step 1: Prepare Configuration File

### Copy Example Configuration

```bash
cd d:\AKS_Terraform
copy terraform.tfvars.example terraform.tfvars
```

### Edit terraform.tfvars

Update the following values in `terraform.tfvars`:

```hcl
# **REQUIRED** - Change these values
resource_group_name = "rg-aks-prod"        # Your resource group name
location             = "eastus"             # Your Azure region
cluster_name         = "aks-myapp-prod"    # Your cluster name
project_name         = "myapp"              # Your project short name (max 10 chars)
environment          = "prod"               # dev, staging, or prod

# **OPTIONAL** - Adjust based on your needs
node_count           = 3
min_node_count       = 1
max_node_count       = 5
vm_size              = "Standard_D2s_v3"
kubernetes_version   = "1.30"

# Security - Add your IP ranges if using API server restrictions
enable_api_server_authorized_ip_ranges = false  # Set to true if needed
# api_server_authorized_ip_ranges = ["203.0.113.0/24"]
```

### Naming Convention Validation

Verify your chosen names follow Azure conventions:

- **Resource Group**: 1-90 alphanumeric, hyphens, underscores
- **Cluster Name**: 1-63 lowercase alphanumeric
- **Project Name**: 1-10 lowercase alphanumeric (no hyphens)

**Examples:**
- ✅ Valid: `rg-aks-prod`, `aks-myapp-prod`, `myapp`
- ❌ Invalid: `RG_AKS_PROD`, `aks-my-app-prod` (22 chars, too long for combined names)

## Step 2: Initialize Terraform

### Run Initialization

```bash
cd d:\AKS_Terraform
terraform init
```

**Expected Output:**
```
Terraform has been successfully configured!
```

**Troubleshooting:**
- If you see provider errors, ensure internet connectivity
- Check Azure CLI authentication: `az account show`

### Validate Configuration

```bash
terraform validate
```

**Expected Output:**
```
Success! The configuration is valid.
```

**If validation fails:**
- Check `terraform.tfvars` syntax (JSON-like format)
- Ensure all variable values are valid (check error message)
- Review variable definitions in `variables.tf`

## Step 3: Plan Deployment

### Generate Execution Plan

```bash
terraform plan -out=tfplan
```

This will:
1. Read all `.tf` files
2. Connect to Azure to check existing resources
3. Generate a plan showing what will be created
4. Save the plan to `tfplan` file

### Review the Plan

The output should show:
- **Resource Group**: 1 new
- **Virtual Network**: 1 new
- **Subnet**: 1 new
- **Network Security Group**: 1 new
- **AKS Cluster**: 1 new
- **Log Analytics Workspace** (if enabled): 1 new
- **Container Registry** (if enabled): 1 new
- **Plus supporting resources**: ~15-20 total

**Plan format:**
```
Terraform will perform the following actions:

  # azurerm_resource_group.aks_rg will be created
  + resource "azurerm_resource_group" "aks_rg" {
      + id       = (known after apply)
      + location = "eastus"
      + name     = "rg-aks-prod"
      ...
    }

  ... (more resources)

Plan: 20 to add, 0 to change, 0 to destroy.
```

### Common Plan Issues

**Issue: Resource already exists**
```
Error: A resource with the ID already exists
```
**Solution**: Use different names in `terraform.tfvars`

**Issue: Insufficient quota**
```
Error: creating compute/virtualmachine: ... quota exceeded
```
**Solution**: 
- Request quota increase via Azure Portal
- Reduce `node_count` or `max_node_count`
- Use smaller `vm_size`

## Step 4: Apply Configuration

### Apply the Plan

```bash
terraform apply tfplan
```

**Important**: This will start creating resources in your Azure subscription and may take **15-20 minutes**.

**Expected Output:**
```
Applying the plan...

azurerm_resource_group.aks_rg: Creating...
azurerm_resource_group.aks_rg: Creation complete after 1s [id=/subscriptions/.../resourceGroups/rg-aks-prod]
azurerm_virtual_network.aks_vnet: Creating...
azurerm_user_assigned_identity.aks_identity: Creating...
...

Apply complete! Resources: 20 added, 0 changed, 0 destroyed.

Outputs:
aks_cluster_fqdn = "aks-myapp-prod.eastus.azmk8s.io"
aks_cluster_name = "aks-myapp-prod"
...
```

### During Deployment

While Terraform is running:
- Monitor the Azure Portal to see resources being created
- Do NOT interrupt the process (Ctrl+C)
- Network setup takes ~5 minutes
- AKS cluster creation takes ~10-15 minutes

### Monitor Progress (Optional)

In another terminal:

```bash
# View resources being created
az group show --name $(terraform output -raw resource_group_name)

# List AKS clusters
az aks list --output table

# Check AKS creation status
az aks show --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name)
```

## Step 5: Verify Deployment

### Check Terraform State

```bash
# List all created resources
terraform state list

# Show specific resource
terraform state show azurerm_kubernetes_cluster.aks_cluster
```

### Verify in Azure Portal

```bash
# Open Azure Portal and navigate to:
# Home > Resource Groups > [your-resource-group-name]

# You should see:
# - AKS cluster
# - Virtual network
# - Container registry (if enabled)
# - Log Analytics workspace (if enabled)
```

### Check Cluster Status

```bash
# Get cluster details
az aks show --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name) -o table

# Expected output should show:
# - PowerState: Running
# - ProvisioningState: Succeeded
```

## Step 6: Configure kubectl

### Get Credentials

```bash
# Method 1: Using Terraform outputs
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name) \
  --overwrite-existing

# Method 2: Using hardcoded names
az aks get-credentials \
  --resource-group rg-aks-prod \
  --name aks-myapp-prod \
  --overwrite-existing
```

This updates your `~/.kube/config` file.

### Verify kubectl Access

```bash
# Test cluster connectivity
kubectl cluster-info

# Expected output:
# Kubernetes control plane is running at https://aks-myapp-prod.eastus.azmk8s.io:443
# CoreDNS is running at https://aks-myapp-prod.eastus.azmk8s.io:443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

## Step 7: Verify Cluster Nodes

### Check Nodes

```bash
# List all nodes
kubectl get nodes

# Expected output:
# NAME                                STATUS   ROLES   AGE   VERSION
# aks-default-12345678-vmss000000    Ready    agent   5m    v1.30.0
# aks-default-12345678-vmss000001    Ready    agent   5m    v1.30.0
# aks-default-12345678-vmss000002    Ready    agent   5m    v1.30.0
```

### Check System Pods

```bash
# View system pods
kubectl get pods --namespace kube-system

# Expected output shows kube-system pods running
# coredns, kube-proxy, azure-cni, metrics-server, etc.
```

### Check Node Details

```bash
# Get detailed node information
kubectl describe node <node-name>

# Check allocated resources
kubectl top nodes
```

## Step 8: Test Cluster

### Deploy Test Application

```bash
# Create a namespace
kubectl create namespace test

# Deploy a test pod
kubectl run test-pod \
  --image=mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11 \
  --namespace test

# Check pod status
kubectl get pods --namespace test

# Access pod shell (if running)
kubectl exec -it test-pod --namespace test -- /bin/bash

# Delete test resources
kubectl delete namespace test
```

## Step 9: Post-Deployment Configuration

### View Outputs

```bash
# Display all Terraform outputs
terraform output

# Display specific output
terraform output aks_cluster_fqdn
terraform output aks_cluster_name
terraform output container_registry_url
```

### Save Configuration

```bash
# Export outputs to JSON
terraform output -json > outputs.json

# Export kubeconfig to file (optional)
kubectl config view --raw > kubeconfig.yaml
```

### Container Registry (if enabled)

```bash
# Login to ACR
az acr login --name $(terraform output -raw container_registry_name)

# Test push (if you have a Docker image)
# docker tag myimage:latest $(terraform output -raw container_registry_url)/myimage:latest
# docker push $(terraform output -raw container_registry_url)/myimage:latest
```

### Enable Monitoring

Access Container Insights:

```bash
# Get Log Analytics workspace
terraform output log_analytics_workspace_name

# Open Azure Portal:
# Navigate to: Your AKS Cluster > Insights > View Container Insights
```

## Deployment Checklist

- [ ] Prerequisites installed and verified
- [ ] `terraform.tfvars` created and configured
- [ ] `terraform init` completed successfully
- [ ] `terraform validate` passed
- [ ] `terraform plan` reviewed and saved
- [ ] `terraform apply` completed (15-20 minutes)
- [ ] Resources visible in Azure Portal
- [ ] `az aks get-credentials` executed
- [ ] `kubectl cluster-info` shows connected
- [ ] `kubectl get nodes` shows all nodes Ready
- [ ] Test pod deployment successful
- [ ] Monitoring (Log Analytics) accessible

## Common Deployment Scenarios

### Development Cluster

```hcl
# In terraform.tfvars
environment         = "dev"
node_count          = 1
min_node_count      = 1
max_node_count      = 2
vm_size             = "Standard_B2s"  # Budget option
enable_log_analytics = true
enable_container_registry = false     # Optional
```

### Production Cluster

```hcl
# In terraform.tfvars
environment         = "prod"
node_count          = 3
min_node_count      = 2
max_node_count      = 10
vm_size             = "Standard_D4s_v3"  # More resources
enable_log_analytics = true
enable_container_registry = true
enable_api_server_authorized_ip_ranges = true
api_server_authorized_ip_ranges = ["203.0.113.0/24"]  # Restrict access
```

## Troubleshooting Common Errors

### Error: "The subscription quota"

```bash
# Check current quotas
az vm list-usage --location eastus

# Solution options:
# 1. Use smaller vm_size
# 2. Reduce node_count
# 3. Request quota increase in Azure Portal
```

### Error: "Resource already exists"

```bash
# Solution:
# 1. Use different resource_group_name
# 2. Or delete existing resource first:
az group delete --name existing-rg-name --yes
```

### Error: "Insufficient permissions"

```bash
# Verify your Azure role
az role assignment list --query "[].roleDefinitionName"

# Solution:
# Contact subscription admin to assign Contributor role
```

### kubectl: Connection refused

```bash
# Solution: Reconfigure credentials
az aks get-credentials --resource-group rg-name --name cluster-name --overwrite-existing

# Or use specific kubeconfig
export KUBECONFIG=~/.kube/config:./kubeconfig.yaml
```

## Next Steps

After successful deployment:

1. **Install Ingress Controller**
   ```bash
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm repo update
   helm install nginx-ingress ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace
   ```

2. **Setup Persistent Storage**
   ```bash
   kubectl apply -f - <<EOF
   apiVersion: storage.k8s.io/v1
   kind: StorageClass
   metadata:
     name: managed-premium
   provisioner: disk.csi.azure.com
   parameters:
     skuname: Premium_LRS
   reclaimPolicy: Delete
   EOF
   ```

3. **Configure RBAC**
   ```bash
   # Create namespace and role bindings
   kubectl create namespace production
   kubectl create serviceaccount app-user -n production
   ```

4. **Enable Monitoring**
   - Access Container Insights in Azure Portal
   - Configure custom alerts
   - Setup dashboards

5. **Setup CI/CD**
   - Configure ACR webhooks
   - Setup GitHub Actions / Azure DevOps pipelines
   - Implement GitOps workflows

## Support and Resources

- [Terraform AKS Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster)
- [Azure AKS Documentation](https://learn.microsoft.com/en-us/azure/aks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Azure CLI Reference](https://learn.microsoft.com/en-us/cli/azure/aks)

---

**Last Updated**: April 22, 2026
