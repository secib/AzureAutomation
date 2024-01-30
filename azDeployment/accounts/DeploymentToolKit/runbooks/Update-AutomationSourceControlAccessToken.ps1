param (
    [Parameter (Mandatory = $false)]
    [string]$ResourceGroupName = "Automation",

    [Parameter (Mandatory = $false)]
    [string]$VaultName = "AzDeploymentToolkit",

    [Parameter (Mandatory = $false)]
    [string]$SecretName = "GithubPersonalAccessToken"
)

# Ensures you do not inherit an AzContext in your runbook
$null = Disable-AzContextAutosave -Scope Process

# Connect to Azure with system-assigned managed identity 
$null = (Connect-AzAccount -Identity).context

# Get webhook payload validation secret from keyvault
$secret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName -ErrorAction Stop

# Check if secret has been updated in last 24h meaning this runbook should run at least one time a day.
if (((Get-Date).ToUniversalTime() - $secret.Updated.ToUniversalTime()) -lt (New-TimeSpan -Days 1))
{
    [array]$managedSubscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" }
    Write-Output "Found $($managedSubscriptions.Count) managed suscriptions"

    foreach ($subscription in $managedSubscriptions)
    {
        Write-Output "TenantId $($subscription.HomeTenantId) - Subscription $($subscription.Id)"
        $null = Set-AzContext -Subscription $subscription.Id -ErrorAction Stop
        Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName | Get-AzAutomationSourceControl | Where-Object { $_.SourceType -eq "GitHub" } | Update-AzAutomationSourceControl -AccessToken $secret.SecretValue
    }
}
