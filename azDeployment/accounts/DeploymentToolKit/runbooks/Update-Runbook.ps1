workflow Update-RunbookWorkflow
{
    param (
        [Parameter(Mandatory)]
        [object]$GitHubContent
    )
    
    # Ensures you do not inherit an AzContext in your runbook
    $null = Disable-AzContextAutosave -Scope Process
    
    # Connect to Azure with system-assigned managed identity 
    $null = (Connect-AzAccount -Identity).context    
    
    $gitObject = $GitHubContent | ConvertFrom-Json
    $folderPath = $gitObject.Path.Substring(0, $gitObject.Path.lastIndexOf('/'))

    $subscriptions = Get-AzSubscription | Where-Object { $_.ExtendedProperties.ManagedByTenants }

    foreach -Parallel ($subscription in $subscriptions)
    {
        $azContext = Set-AzContext -Subscription $subscription.Id -ErrorAction Stop
        Get-AzAutomationAccount | Get-AzAutomationSourceControl | Where-Object { $_.FolderPath -match $folderPath }
    }    
}
