[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $SubscriptionName = "crayon",

    [Parameter()]
    [string]
    $ResourceGroupName = "Automation",

    [Parameter()]
    [string]
    $Location = "francecentral"
)

# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process | Out-Null

$sub = Get-AzSubscription -ErrorAction SilentlyContinue
if ($null -eq $sub)
{
    # $azProfile = Connect-AzAccount -Identity -Subscription $SubscriptionName -ErrorAction Stop
    $azProfile = Connect-AzAccount -Subscription $SubscriptionName -ErrorAction Stop
}

# Create resource group
$resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

if ($null -eq $resourceGroup)
{
    try
    {
        Write-Host "Creating new resource group $ResourceGroupName."
        $resourceGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction Stop
        Write-Host "Resource group $ResourceGroupName created sucessfully."
    }
    catch
    {
        Write-Warning $error[0].Exception.Message
        continue
    }
}

# Create automation account
$automationAccountName = "device-monitoring"

$automationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $automationAccountName -ErrorAction SilentlyContinue

if ($null -eq $automationAccount)
{
    try
    {
        Write-Host "Creating new automation account $automationAccountName."
        $automationAccount = New-AzAutomationAccount -Name $automationAccountName -ResourceGroupName $ResourceGroupName -Location $Location -AssignSystemIdentity -ErrorAction Stop
        Write-Host "Automation account $automationAccountName created sucessfully."
    }
    catch
    {
        continue
    }
}

# Grant Graph API permissions to automation account
$servicePrincipalId = $automationAccount.Identity.PrincipalId

$resourceAppId = '00000002-0000-0ff1-ce00-000000000000' # graph api
$permissionList = 'Exchange.ManageAsApp'

$servicePrincipal = (Get-AzADServicePrincipal -ObjectId $servicePrincipalId)
if (!$servicePrincipal) { throw "Service principal '$servicePrincipalId' doesn't exist" }

# get application whose permissions will be granted
$resourceServicePrincipal = Get-AzADServicePrincipal -Filter "appId eq '$resourceAppId'"
if (!$resourceServicePrincipal) { throw "Resource '$resourceAppId' doesn't exist" }

# grant requested permissions
foreach ($permission in $permissionList)
{
    $AppRole = $resourceServicePrincipal.AppRole | Where-Object { $_.Value -eq $permission -and $_.AllowedMemberType -contains "Application" }
    if (!$AppRole)
    {
        Write-Warning "Application permission '$permission' wasn't found in '$resourceAppId' application. Therefore it cannot be added."
        continue
    }

    Add-AzADAppPermission -ObjectId $servicePrincipal.Id -PermissionId $AppRole.Id -ApiId $resourceServicePrincipal.AppId

    Update-AzADServicePrincipal -ObjectId $servicePrincipal.Id -AppRole @(@{
        AppRoleId = $AppRole.Id
        PrincipalId = $servicePrincipal.Id
        ResourceId = $resourceServicePrincipal.Id
    })

}

# Create automation runbook
$automationRunbookName = "Set_device_hostname"

$automationRunbook = Get-AzAutomationRunbook -Name $automationRunbookName -ResourceGroupName $ResourceGroupName -AutomationAccountName $automationAccountName -ErrorAction SilentlyContinue

if ($null -eq $automationRunbook)
{
    try
    {
        Write-Host "Creating new automation runbook $automationRunbookName."
        $automationRunbook = New-AzAutomationRunbook -Name $automationRunbookName -ResourceGroupName $ResourceGroupName -Location $Location -AutomationAccountName $automationAccountName -Type PowerShell - -ErrorAction Stop
        Write-Host "Automation runbook $automationRunbookName created sucessfully."
    }
    catch
    {
        Write-Warning $error[0].Exception.Message
    }
}