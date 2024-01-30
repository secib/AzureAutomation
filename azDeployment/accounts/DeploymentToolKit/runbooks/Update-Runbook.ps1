workflow Update-Runbook
{
    param (
        [Parameter(Mandatory)]
        [object]$GitHubContent
    )
    
    Write-Output $GitHubContent

    $folderPath = $GitHubContent.Path.Substring(0, $GitHubContent.Path.lastIndexOf('/'))

    Write-Output $folderPath

    # Ensures you do not inherit an AzContext in your runbook
    $null = Disable-AzContextAutosave -Scope Process
    
    # Connect to Azure with system-assigned managed identity 
    $null = (Connect-AzAccount -Identity).context    

    [array]$subscriptions = Get-AzSubscription | Where-Object { $_.ExtendedProperties.ManagedByTenants }

    foreach -Parallel ($subscription in $subscriptions)
    {
        Write-Output $subscription.Id
        $azContext = Set-AzContext -Subscription $subscription.Id -ErrorAction Stop
        Get-AzAutomationAccount | Get-AzAutomationSourceControl | Where-Object { $_.FolderPath -match $folderPath } | Start-AzAutomationSourceControlSyncJob
    }    
}
