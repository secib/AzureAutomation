[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [object]
    $WebhookData
)

class Body
{
    [string]$Organization
}

# exit if no provided webhookdata
if ($null -eq $WebhookData)
{
    Write-Error "No webhook data provided."
    exit
}

# Logic to allow for testing in Test pane
if (-Not $WebhookData.RequestBody)
{ 
    $WebhookData = $WebhookData | ConvertFrom-Json
}

try
{
    [Body]$requestBody = $WebhookData.RequestBody | ConvertFrom-Json -ErrorAction Stop
}
catch
{
    Write-Error "Unexpected request body."
    exit
}
finally
{
    Write-Output $WebhookData.RequestBody
}

# Import the ExchangeOnlineManagement Module we imported into the Automation Account
Import-Module ExchangeOnlineManagement

Connect-ExchangeOnline -ManagedIdentity -Organization $requestBody.Organization

class TaskResult
{
    [string]$TaskName
    [bool]$IsCompliant
}

class Task
{
    [string]$Name

    Task([string]$name)
    {
        $this.Name = $name
    }

    [bool] IsCompliant()
    {
        throw("Must Override Method")
    }

    [void] MakeCompliant()
    {
        throw("Must Override Method")
    }

    [TaskResult] Run()
    {
        $isCompliant = $this.IsCompliant()

        If (-not $isCompliant)
        {
            $this.MakeCompliant()
            $isCompliant = $this.IsCompliant()
        }

        return [TaskResult]@{
            TaskName    = $this.Name
            IsCompliant = $isCompliant
        }
    }
}

class EnableOrganizationCustomizationTask : Task
{
    EnableOrganizationCustomizationTask() : base ("EnableOrganizationCustomization")
    {
    }

    [bool]IsCompliant()
    {
        return -not ((Get-OrganizationConfig).IsDehydrated)
    }

    [void]MakeCompliant()
    {
        Enable-OrganizationCustomization
    }
}

class UnifiedAuditLogIngestionEnabledTask : Task
{
    UnifiedAuditLogIngestionEnabledTask() : base ("UnifiedAuditLogIngestionEnabled")
    {
    }

    [bool]IsCompliant()
    {
        return ((Get-AdminAuditLogConfig).UnifiedAuditLogIngestionEnabled)
    }

    [void]MakeCompliant()
    {
        Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled:$true
    }
}

[Task[]]$taskList = @(
    [EnableOrganizationCustomizationTask]::new()
    [UnifiedAuditLogIngestionEnabledTask]::new()
)

$taskResultCollection = [System.Collections.ArrayList]::new()

foreach ($task in $taskList)
{
    $null = $taskResultCollection.Add($task.Run())
}

Write-Output $taskResultCollection