# AKS Security Best Practices and Configuration

This document outlines security best practices and hardening recommendations for the AKS cluster deployed with this Terraform configuration.

## Table of Contents

- [Network Security](#network-security)
- [Identity and Access Control](#identity-and-access-control)
- [Data Protection](#data-protection)
- [Monitoring and Audit](#monitoring-and-audit)
- [Pod Security](#pod-security)
- [Container Registry Security](#container-registry-security)
- [Secrets Management](#secrets-management)
- [API Server Security](#api-server-security)
- [Security Checklist](#security-checklist)

## Network Security

### Virtual Network Isolation

The configuration creates isolated networking:

```hcl
# Dedicated subnet for AKS
vnet_address_space = ["10.0.0.0/8"]
subnet_address_prefix = ["10.1.0.0/16"]
```

**Best Practices:**
- ✅ Use non-overlapping CIDR ranges
- ✅ Separate AKS from other workloads
- ✅ Implement network segmentation per environment

### Network Security Group (NSG)

Default NSG rules restrict inbound traffic:

```
Rule Priority: 100
- Allow: TCP/443 (Kubernetes API)
Rule Priority: 4096
- Deny: All other inbound traffic
```

**Additional Hardening:**

```bash
# Add more restrictive rules
az network nsg rule create \
  --resource-group <rg-name> \
  --nsg-name <nsg-name> \
  --name AllowSSHFromJumpbox \
  --priority 200 \
  --source-address-prefixes 10.0.1.0/24 \
  --destination-port-ranges 22 \
  --access Allow \
  --protocol Tcp
```

### Network Policy

Enable Azure Network Policy for pod-to-pod communication:

```hcl
network_policy = "azure"  # Options: azure, calico
```

**Recommended Network Policies:**

```yaml
# Deny all inbound traffic by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress

---
# Allow DNS queries
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
spec:
  podSelector:
    matchLabels: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

### Private Endpoint Configuration (Optional)

For enhanced security, enable private endpoints:

```bash
# Uncomment in container_registry.tf to enable
# This restricts ACR access to the VNet only
```

### Outbound Traffic Control

Configure outbound via load balancer or NAT gateway:

```hcl
outbound_type = "loadBalancer"  # or "userDefinedRouting", "managedNATGateway"
```

**For restrictive egress:**

```bash
# Create User Defined Route for controlling egress
az network route-table create \
  --resource-group <rg-name> \
  --name aks-routes
```

## Identity and Access Control

### Managed Identity

The configuration uses system-managed identities:

```hcl
identity {
  type         = "UserAssigned"
  identity_ids = [azurerm_user_assigned_identity.aks_identity.id]
}
```

**Best Practices:**
- ✅ Always use managed identities (never service principal)
- ✅ Use system-assigned for node pool
- ✅ Use user-assigned for control plane

### RBAC Configuration

RBAC is enabled by default:

```hcl
role_based_access_control_enabled = true
```

**Recommended RBAC Setup:**

```bash
# Create namespace-specific service accounts
kubectl create namespace production

# Create role with minimal permissions
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployment-reader
  namespace: production
rules:
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets"]
  verbs: ["get", "list", "watch"]
EOF

# Bind role to service account
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deployment-reader-binding
  namespace: production
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: deployment-reader
subjects:
- kind: ServiceAccount
  name: app-reader
  namespace: production
EOF
```

### Azure AD Integration (Optional)

For enterprise environments:

```bash
# Create Azure AD group for cluster admins
az ad group create --display-name "AKS-Admins" --mail-nickname "aks-admins"

# Get the object ID
groupId=$(az ad group show --group "AKS-Admins" --query id -o tsv)

# Assign cluster admin role
az role assignment create \
  --assignee $groupId \
  --role "Azure Kubernetes Service Cluster Admin Role" \
  --scope $(terraform output -raw aks_cluster_id)
```

**Recommended Terraform addition:**

```hcl
# Add to main.tf for Azure AD integration
azure_active_directory_role_based_access_control {
  managed                = true
  tenant_id              = data.azurerm_client_config.current.tenant_id
  admin_group_object_ids = [var.admin_group_object_id]  # Add to variables
}
```

## Data Protection

### Encryption

#### Node Disk Encryption

```hcl
os_disk_type = "Managed"  # Automatically encrypted with platform key
```

**For customer-managed keys:**

```bash
# Create Key Vault
az keyvault create \
  --resource-group <rg-name> \
  --name kv-aks-<random>

# Create encryption key
az keyvault key create \
  --vault-name kv-aks-<random> \
  --name aks-encryption-key

# Grant AKS identity access to key
key_id=$(az keyvault key show \
  --vault-name kv-aks-<random> \
  --name aks-encryption-key \
  --query id -o tsv)

az role assignment create \
  --assignee $(terraform output -raw aks_managed_identity_id) \
  --role "Key Vault Crypto Service Encryption User" \
  --scope $key_id
```

#### Etcd Encryption

AKS manages etcd encryption automatically. To verify:

```bash
# Check encryption status
az aks show \
  --resource-group <rg-name> \
  --name <cluster-name> \
  --query "enableRbac"
```

#### TLS for Pod Communication

```yaml
# Example using Istio for mTLS
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
spec:
  mtls:
    mode: STRICT  # Enforce mTLS for all services
```

### Backup Strategy

Implement persistent volume backups:

```bash
# Deploy Velero for cluster backup
helm repo add velero https://vmware-tanzu.github.io/helm-charts
helm repo update
helm install velero velero/velero \
  --namespace velero --create-namespace \
  --set configuration.backupStorageLocation.bucket=<backup-bucket> \
  --set configuration.backupStorageLocation.provider=azure
```

## Monitoring and Audit

### Audit Logging

Enabled by default via Log Analytics:

```hcl
enabled_log {
  category = "kube-audit"
}
```

**Query audit logs:**

```bash
# Using Azure CLI
az monitor log-analytics query \
  --workspace $(terraform output -raw log_analytics_workspace_id) \
  --analytics-query "
  AzureDiagnostics
  | where Category == 'kube-audit'
  | where verb in ('create', 'delete', 'patch')
  | order by TimeGenerated desc
  | limit 100"
```

### Container Insights

Enabled monitoring configuration:

```hcl
oms_agent {
  enabled                    = true
  log_analytics_workspace_id = azurerm_log_analytics_workspace.aks_workspace[0].id
}
```

**Setup custom alerts:**

```bash
# CPU usage alert
az monitor metrics alert create \
  --name alert-high-cpu \
  --resource-group $(terraform output -raw resource_group_name) \
  --scopes $(terraform output -raw aks_cluster_id) \
  --condition "avg node_cpu_usage_percentage > 80" \
  --window-size PT5M \
  --evaluation-frequency PT1M
```

### Azure Policy

Azure Policy is enabled for compliance:

```hcl
azure_policy_enabled = true
```

**Assign policies:**

```bash
# Enforce HTTPS only
az policy assignment create \
  --name enforce-https \
  --policy "6c112d4e-5bc7-47ae-a041-ea2151884743" \
  --scope $(terraform output -raw aks_cluster_id)
```

## Pod Security

### Pod Security Standards (Kubernetes 1.25+)

```yaml
# Label namespace with pod security standard
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Security Context Examples

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: myapp:latest
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
```

### Resource Quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: production
spec:
  hard:
    requests.cpu: "10"
    requests.memory: "20Gi"
    limits.cpu: "20"
    limits.memory: "40Gi"
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values: ["default"]
```

### Limit Ranges

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: compute-limits
  namespace: production
spec:
  limits:
  - type: Pod
    max:
      cpu: "2"
      memory: "1Gi"
    min:
      cpu: "100m"
      memory: "128Mi"
  - type: Container
    max:
      cpu: "1"
      memory: "512Mi"
    min:
      cpu: "50m"
      memory: "64Mi"
    default:
      cpu: "500m"
      memory: "256Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
```

## Container Registry Security

### ACR Best Practices

The configuration creates a secure ACR:

```hcl
azurerm_container_registry "aks_acr" {
  admin_enabled = false  # Disable admin account
}
```

**Additional hardening:**

```bash
# Enable content trust (image signing)
az acr config content-trust update \
  --registry <registry-name> \
  --status enabled

# Scan images for vulnerabilities
az acr config soft-delete update \
  --registry <registry-name> \
  --status enabled

# Set retention policy
az acr config retention update \
  --registry <registry-name> \
  --days 90
```

### Image Pull Secrets

The configuration automatically grants pull access via managed identity. For additional security:

```bash
# Create pull secrets for manual override
kubectl create secret docker-registry regcred \
  --docker-server=$(terraform output -raw container_registry_url) \
  --docker-username=<username> \
  --docker-password=<password>
```

## Secrets Management

### Azure Key Vault Integration

```bash
# Create Key Vault
az keyvault create \
  --resource-group $(terraform output -raw resource_group_name) \
  --name kv-aks-<random>

# Grant AKS identity access
az role assignment create \
  --assignee $(terraform output -raw aks_managed_identity_id) \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/$(az account show -q id)/resourcegroups/$(terraform output -raw resource_group_name)/providers/Microsoft.KeyVault/vaults/kv-aks-<random>"

# Install secrets provider
helm repo add csi-secrets-store-provider-azure https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/charts
helm install csi-secrets-store-provider-azure/secrets-store-csi-driver-provider-azure \
  --namespace kube-system \
  --set secrets-store-csi-driver.install=true
```

### Kubernetes Secrets Best Practices

```bash
# Use sealed secrets
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets -n kube-system sealed-secrets/sealed-secrets

# Encrypt secrets in etcd (handled by AKS automatically)
# Never commit secrets to git
# Rotate secrets regularly
```

## API Server Security

### Authorized IP Ranges

Configure access to API server:

```hcl
enable_api_server_authorized_ip_ranges = true
api_server_authorized_ip_ranges = [
  "203.0.113.0/24",   # Your office IP
  "198.51.100.0/24",  # Your VPN IP
]
```

**Retrieve kubeconfig from authorized location:**

```bash
# From authorized IP
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name)
```

## Security Checklist

### Deployment Phase

- [ ] Enable all security features (RBAC, Network Policy, Azure Policy)
- [ ] Configure API server authorized IP ranges
- [ ] Enable audit logging to Log Analytics
- [ ] Configure NSG rules restrictively
- [ ] Use managed identities (not service principals)
- [ ] Enable container registry image scanning
- [ ] Disable admin account on ACR

### Runtime Phase

- [ ] Configure Pod Security Standards per namespace
- [ ] Implement network policies for pod communication
- [ ] Set resource quotas and limit ranges
- [ ] Define security contexts for all pods
- [ ] Enable Azure Policy compliance checks
- [ ] Monitor audit logs regularly
- [ ] Implement secrets rotation

### Operational Phase

- [ ] Regular cluster updates and patches
- [ ] Monitor and respond to security alerts
- [ ] Review and audit RBAC assignments
- [ ] Backup and restore procedures tested
- [ ] Security assessment quarterly
- [ ] Update admission controllers (Pod Security Standards)
- [ ] Regular penetration testing

### Compliance

- [ ] Document security controls
- [ ] Maintain audit trails
- [ ] Regular compliance reviews
- [ ] Follow CIS Kubernetes Benchmark
- [ ] Implement security scanning in CI/CD
- [ ] Data residency requirements met

## Additional Resources

- [Azure Security Baseline for AKS](https://learn.microsoft.com/en-us/security/benchmark/azure/mcsb-network-security)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [Azure Policy for AKS](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/policy-for-kubernetes)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)

---

**Last Updated**: April 22, 2026  
**Framework**: Azure Well-Architected Framework - Security Pillar
