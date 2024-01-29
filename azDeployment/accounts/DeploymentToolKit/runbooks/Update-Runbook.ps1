workflow Update-Runbook
{
    param (
        [Parameter(Mandatory)]
        [string]$ScriptContent,
    
        [Parameter(Mandatory)]
        [string]$ScriptPath
    )
    
    # Ensures you do not inherit an AzContext in your runbook
    $null = Disable-AzContextAutosave -Scope Process
    
    # Connect to Azure with system-assigned managed identity 
    $null = (Connect-AzAccount -Identity).context    
    
    $scriptfile = $ScriptPath.Split("/")[-1]
    $runbookName = $scriptfile.TrimEnd(".ps1")

    $subscriptions = Get-AzSubscription | Where-Object { $_.ExtendedProperties.ManagedByTenants }

    foreach -Parallel ($subscription in $subscriptions)
    {
        $azContext = Set-AzContext -Subscription $subscription.Id -ErrorAction Stop
        $ScriptContent | Set-Content -Path $scriptfile -Encoding UTF8
        Import-AzAutomationRunbook -Path $scriptfile -Name $runbookName -Type PowerShell -AutomationAccountName "DeploymentToolKit" -ResourceGroupName "AzDeployment" -Force -Published
    }    
}
