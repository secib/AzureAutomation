workflow Update-Runbook
{
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$GitHubContent
    )
    
    # Ensures you do not inherit an AzContext in your runbook
    $null = Disable-AzContextAutosave -Scope Process
    
    # Connect to Azure with system-assigned managed identity 
    $null = (Connect-AzAccount -Identity).context    
    
    $gitObject = $GitHubContent | ConvertFrom-Json    
    $runbookName = $gitObject.Name.TrimEnd(".ps1")
    $gitObject.ContentAsString | Set-Content -Path $gitObject.Name -Encoding UTF8

    Write-Output $gitObject

    $subscriptions = Get-AzSubscription | Where-Object { $_.ExtendedProperties.ManagedByTenants }

    foreach -Parallel ($subscription in $subscriptions)
    {
        $azContext = Set-AzContext -Subscription $subscription.Id -ErrorAction Stop
        Import-AzAutomationRunbook -Path $gitObject.Name -Name $runbookName -Type PowerShell -AutomationAccountName "DeploymentToolKit" -ResourceGroupName "AzDeployment" -Force -Published
    }    
}
