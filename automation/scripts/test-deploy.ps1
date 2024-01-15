[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $SubscriptionName = "crayon",

    [Parameter()]
    [string]
    $ResourceGroupName = "Automation"
)

$accessToken = Read-Host -AsSecureString

if ($null -eq $accessToken)
{
    Write-Error "no access token provided"
    exit
}

$azContext = Set-AzContext -Subscription $SubscriptionName -ErrorAction Stop
$workingDir = "C:\Users\SCLAVON\repos\AzureAutomation\automation\accounts"

# Administrative task
$params = @{
    SubscriptionName          = $SubscriptionName
    ResourceGroupName         = $ResourceGroupName
    DeploymentName            = "administrativeTaskDeployment_{0}" -f (get-date).ToFileTimeUtc()
    TemplateFile              = Join-Path $workingDir "\AdministrativeTask\templates\armTemplate_administrativeTask.json"
    TemplateParameterFile     = Join-Path $workingDir "\AdministrativeTask\templates\armTemplate_administrativeTask.parameters.json"
    AccessToken               = $accessToken
    ApplicationRoleAssignment = @{ ResourceAppId = "00000003-0000-0000-c000-000000000000"; ApplicationRole = 'User.ReadWrite.All' }
}

$result = & (Join-Path $PSScriptRoot New-AutomationAccount.ps1) @params

# Save webhookUri to Keeper
$webhookUri = $result["webhookUri"].Value

# Baseline
$params = @{
    SubscriptionName          = $SubscriptionName
    ResourceGroupName         = $ResourceGroupName
    DeploymentName            = "baselineDeployment_{0}" -f (get-date).ToFileTimeUtc()
    TemplateFile              = Join-Path $workingDir "\Baseline\templates\baseline.json"
    TemplateParameterFile     = Join-Path $workingDir "\Baseline\templates\baseline.parameters.json"
    AccessToken               = $accessToken
    ApplicationRoleAssignment = @(
        @{ ResourceAppId = "00000002-0000-0ff1-ce00-000000000000"; ApplicationRole = 'Exchange.ManageAsApp' },
        @{ ResourceAppId = "00000003-0000-0000-c000-000000000000"; ApplicationRole = 'Directory.Read.All' }
    )
}

$result = & (Join-Path $PSScriptRoot New-AutomationAccount.ps1) @params

# Save webhookUri to Keeper
$webhookUri = $result["webhookUri"].Value

# Register Secib Admin Toolkit service principal
$applicationId = "0dd78a24-5595-47bc-be51-0892f839eb7a"
$roleDefinition = "Automation Contributor"

$servicePrincipal = Get-AzADServicePrincipal -ApplicationId $applicationId

if ($null -eq $servicePrincipal)
{
    Write-Output "Create service principal with applicationId $applicationId..."
    $servicePrincipal = New-AzADServicePrincipal -ApplicationId $applicationId -ErrorAction Stop
}

$servicePrincipal | Out-Host

$resourceGroup = Get-AzresourceGroup -Name $ResourceGroupName
$role = Get-AzRoleDefinition -Name $roleDefinition
$roleAssignment = Get-AzRoleAssignment -ServicePrincipalName $servicePrincipal.AppId -RoleDefinitionName $role.Name -Scope $resourceGroup.ResourceId

if ($null -eq $roleAssignment)
{
    Write-Output "Assigns $roleDefinition RBAC role to the service principal $($servicePrincipal.Id)..."
    $roleAssignment = New-AzRoleAssignment -ServicePrincipalName $servicePrincipal.AppId -RoleDefinitionName $role.Name -Scope $resourceGroup.ResourceId
}

$roleAssignment | Out-Host
