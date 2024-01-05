[CmdletBinding()]
param (
    [Parameter()]
    [object]
    $WebhookData
)

# exit if no provided webhookdata
if ($null -eq $WebhookData)
{
    Write-Error "No webhook data provided."
    continue
}

Write-Output $WebhookData

$Organization = (ConvertFrom-Json -InputObject $WebhookData.RequestBody).Organization

if ($null -eq $Organization)
{
    Write-Error "No provided value for Organization"
    continue
}

Connect-ExchangeOnline -ManagedIdentity -Organization $Organization

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
