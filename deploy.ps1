# Deploy AKS Cluster using Terraform
# This script automates the AKS deployment process

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("init", "plan", "apply", "destroy", "validate", "full")]
    [string]$Action = "plan",
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoApprove,
    
    [Parameter(Mandatory=$false)]
    [string]$VarsFile = "terraform.tfvars"
)

# Colors for output
$colors = @{
    Info    = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
}

function Write-ColorOutput($message, $type = "Info") {
    Write-Host $message -ForegroundColor $colors[$type]
}

function Test-Prerequisites {
    Write-ColorOutput "Checking prerequisites..." "Info"
    
    $missingTools = @()
    
    # Check Terraform
    try {
        $tfVersion = terraform version | Select-Object -First 1
        Write-ColorOutput "✓ Terraform: $tfVersion" "Success"
    } catch {
        $missingTools += "Terraform"
    }
    
    # Check Azure CLI
    try {
        $azVersion = az version | ConvertFrom-Json | Select-Object -ExpandProperty "azure-cli"
        Write-ColorOutput "✓ Azure CLI: $azVersion" "Success"
    } catch {
        $missingTools += "Azure CLI"
    }
    
    # Check kubectl
    try {
        $kubectlVersion = kubectl version --client --output=json | ConvertFrom-Json | Select-Object -ExpandProperty clientVersion | Select-Object -ExpandProperty gitVersion
        Write-ColorOutput "✓ kubectl: $kubectlVersion" "Success"
    } catch {
        $missingTools += "kubectl"
    }
    
    if ($missingTools.Count -gt 0) {
        Write-ColorOutput "Missing required tools: $($missingTools -join ', ')" "Error"
        Write-ColorOutput "Please install the missing tools and try again." "Error"
        exit 1
    }
    
    # Check Azure CLI authentication
    try {
        $account = az account show --query "{subscription:subscription, user:user}" 2>$null | ConvertFrom-Json
        Write-ColorOutput "✓ Azure CLI authenticated as: $($account.user.name)" "Success"
    } catch {
        Write-ColorOutput "✗ Not authenticated with Azure CLI" "Error"
        Write-ColorOutput "Run: az login" "Info"
        exit 1
    }
}

function Test-ConfigFile {
    Write-ColorOutput "Checking configuration file..." "Info"
    
    if (-not (Test-Path $VarsFile)) {
        Write-ColorOutput "✗ Configuration file not found: $VarsFile" "Error"
        Write-ColorOutput "Please copy terraform.tfvars.example to terraform.tfvars and configure it." "Info"
        exit 1
    }
    
    Write-ColorOutput "✓ Configuration file found: $VarsFile" "Success"
}

function Invoke-TerraformInit {
    Write-ColorOutput "`nInitializing Terraform..." "Info"
    
    terraform init
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "✗ Terraform init failed" "Error"
        exit 1
    }
    
    Write-ColorOutput "✓ Terraform initialization complete" "Success"
}

function Invoke-TerraformValidate {
    Write-ColorOutput "`nValidating Terraform configuration..." "Info"
    
    terraform validate
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "✗ Terraform validation failed" "Error"
        exit 1
    }
    
    Write-ColorOutput "✓ Terraform configuration is valid" "Success"
}

function Invoke-TerraformPlan {
    Write-ColorOutput "`nGenerating Terraform plan..." "Info"
    Write-ColorOutput "This will show what resources will be created/modified." "Info"
    
    terraform plan -var-file=$VarsFile -out=tfplan
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "✗ Terraform plan failed" "Error"
        exit 1
    }
    
    Write-ColorOutput "✓ Terraform plan generated successfully" "Success"
    Write-ColorOutput "Review the plan above. Run with 'apply' action to proceed." "Info"
}

function Invoke-TerraformApply {
    Write-ColorOutput "`nApplying Terraform configuration..." "Info"
    Write-ColorOutput "This will create/modify resources in your Azure subscription." "Warning"
    
    if (-not (Test-Path "tfplan")) {
        Write-ColorOutput "Plan file not found. Generating new plan..." "Warning"
        terraform plan -var-file=$VarsFile -out=tfplan
    }
    
    if (-not $AutoApprove) {
        $confirmation = Read-Host "Are you sure you want to apply? Type 'yes' to confirm"
        if ($confirmation -ne "yes") {
            Write-ColorOutput "Operation cancelled." "Warning"
            exit 0
        }
    }
    
    Write-ColorOutput "Applying plan. This may take 15-20 minutes..." "Info"
    terraform apply $(if ($AutoApprove) { "-auto-approve" }) tfplan
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "✗ Terraform apply failed" "Error"
        exit 1
    }
    
    Write-ColorOutput "✓ Terraform apply completed successfully" "Success"
    
    # Display outputs
    Write-ColorOutput "`n--- Deployment Summary ---" "Success"
    terraform output
    
    # Configure kubectl
    Write-ColorOutput "`nConfiguring kubectl..." "Info"
    $resourceGroup = terraform output -raw resource_group_name
    $clusterName = terraform output -raw aks_cluster_name
    
    az aks get-credentials --resource-group $resourceGroup --name $clusterName --overwrite-existing
    Write-ColorOutput "✓ kubectl configured" "Success"
    
    # Verify cluster
    Write-ColorOutput "`nVerifying cluster..." "Info"
    kubectl cluster-info
    kubectl get nodes
}

function Invoke-TerraformDestroy {
    Write-ColorOutput "`nDestroying Terraform resources..." "Warning"
    Write-ColorOutput "This will DELETE all resources created by this configuration." "Error"
    
    $confirmation = Read-Host "Type 'destroy' to confirm deletion"
    if ($confirmation -ne "destroy") {
        Write-ColorOutput "Operation cancelled." "Warning"
        exit 0
    }
    
    terraform destroy -var-file=$VarsFile $(if ($AutoApprove) { "-auto-approve" })
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✓ Resources destroyed successfully" "Success"
    } else {
        Write-ColorOutput "✗ Destroy operation failed" "Error"
        exit 1
    }
}

function Invoke-FullDeployment {
    Write-ColorOutput "Starting full AKS deployment..." "Info"
    
    # Run all steps
    Invoke-TerraformInit
    Invoke-TerraformValidate
    Invoke-TerraformPlan
    
    Write-ColorOutput "`n--- Plan Review Complete ---" "Success"
    $proceed = Read-Host "Proceed with apply? (yes/no)"
    if ($proceed -ne "yes") {
        Write-ColorOutput "Deployment cancelled." "Warning"
        exit 0
    }
    
    Invoke-TerraformApply
}

# Main execution
Write-ColorOutput "╔════════════════════════════════════════════════════════════════════╗" "Info"
Write-ColorOutput "║          Azure Kubernetes Service (AKS) Deployment Script          ║" "Info"
Write-ColorOutput "╚════════════════════════════════════════════════════════════════════╝" "Info"

# Verify prerequisites
Test-Prerequisites
Test-ConfigFile

# Execute action
switch ($Action) {
    "init" {
        Invoke-TerraformInit
    }
    "validate" {
        Invoke-TerraformValidate
    }
    "plan" {
        Invoke-TerraformInit
        Invoke-TerraformValidate
        Invoke-TerraformPlan
    }
    "apply" {
        Invoke-TerraformApply
    }
    "destroy" {
        Invoke-TerraformDestroy
    }
    "full" {
        Invoke-FullDeployment
    }
    default {
        Write-ColorOutput "Unknown action: $Action" "Error"
        exit 1
    }
}

Write-ColorOutput "`n✓ Script execution completed successfully" "Success"
