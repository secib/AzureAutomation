[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [object]
    $WebhookData
)

Import-Module ExchangeOnlineManagement

class Body
{
    [string]$Organization
}

# # exit if no provided webhookdata
if ($null -eq $WebhookData)
{
    Write-Error "No webhook data provided."
    exit
}

# # Logic to allow for testing in Test pane
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

class BaselineResult
{
    [string]$TenantId
    [string]$Organization
    [string]$StartDate
    [string]$EndDate
    [bool]$IsCompliant
    [int]$CompliancyPercentage
    [System.Collections.Generic.List[TaskResult]]$TaskResultCollection
    [System.Collections.Generic.List[string]]$ErrorMessageCollection
    [System.Collections.Generic.List[string]]$WarningMessageCollection

    BaselineResult()
    {
        $this.StartDate = Get-Date -Format "dd-MM-yyyyTHH:mm:ssK"
        $this.TaskResultCollection = [System.Collections.Generic.List[TaskResult]]::new()
        $this.ErrorMessageCollection = [System.Collections.Generic.List[string]]::new()
        $this.WarningMessageCollection = [System.Collections.Generic.List[string]]::new()
    }

    [void]Complete()
    {
        $this.EndDate = Get-Date -Format "dd-MM-yyyyTHH:mm:ssK"

        if ($this.TaskResultCollection.Count -ne 0)
        {
            $this.IsCompliant = $this.TaskResultCollection.IsCompliant -notcontains $false
            $this.CompliancyPercentage = ($this.TaskResultCollection | Where-Object { $_.IsCompliant }).Count / $this.TaskResultCollection.Count * 100
        }
    }
}

class TaskResult
{
    [string]$TaskName
    [string]$StartDate
    [string]$EndDate
    [bool]$IsCompliant
    [System.Collections.Generic.List[string]]$ErrorMessageCollection

    TaskResult([string]$name)
    {
        $this.TaskName = $name
        $this.StartDate = Get-Date -Format "dd-MM-yyyyTHH:mm:ssK"
        $this.ErrorMessageCollection = [System.Collections.Generic.List[string]]::new()
    }

    [void] Complete()
    {
        $this.EndDate = Get-Date -Format "dd-MM-yyyyTHH:mm:ssK"
    }
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
        $taskResult = [TaskResult]::new($this.Name)

        try
        {
            $taskResult.IsCompliant = $this.IsCompliant()
        }
        catch
        {
            $taskResult.ErrorMessageCollection.Add("IsCompliant failed with error {0}" -f $error[0].Exception.Message)
        }

        if (-not $taskResult.IsCompliant)
        {
            try
            {
                $this.MakeCompliant()

                try
                {
                    $taskResult.IsCompliant = $this.IsCompliant()
                }
                catch
                {
                    $taskResult.ErrorMessageCollection.Add("IsCompliant failed with error {0}" -f $error[0].Exception.Message)
                }    
            }
            catch
            {
                $taskResult.ErrorMessageCollection.Add("MakeCompliant failed with error {0}" -f $error[0].Exception.Message)
            }    
        }

        $taskResult.Complete()

        return $taskResult
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

$taskList = [System.Collections.Generic.List[Task]]::new()
$baselineResult = [BaselineResult]::new()

try
{
    Connect-ExchangeOnline -ManagedIdentity -Organization $requestBody.Organization -ErrorAction Stop
}
catch
{
    $baselineResult.ErrorMessageCollection.Add($error[0].Exception.Message)
}

$connectionInformation = Get-ConnectionInformation

if ($connectionInformation.State -eq "Connected")
{
    $baselineResult.TenantId = $connectionInformation.TenantId
    $baselineResult.Organization = $connectionInformation.Organization
    $null = $taskList.Add([EnableOrganizationCustomizationTask]::new())
    $null = $taskList.Add([UnifiedAuditLogIngestionEnabledTask]::new())
}

foreach ($task in $taskList)
{
    $null = $baselineResult.TaskResultCollection.Add($task.Run())
}

$baselineResult.Complete()

if ($connectionInformation.State -eq "Connected")
{
    Disconnect-ExchangeOnline -Confirm:$false
}

Write-Output $baselineResult
Write-Output $baselineResult.TaskResultCollection