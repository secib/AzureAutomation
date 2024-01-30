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

if ((Get-OrganizationConfig).IsDehydrated)
{
    Enable-OrganizationCustomization
}

Write-Output IsDehydrated
(Get-OrganizationConfig).IsDehydrated

if (!(Get-AdminAuditLogConfig).UnifiedAuditLogIngestionEnabled)
{
    Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled:$true
}

Write-Output UnifiedAuditLogIngestionEnabled
(Get-AdminAuditLogConfig).UnifiedAuditLogIngestionEnabled

# tata content toto titi toto enfin!!!! oh!