# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process

# Connect to Azure with system-assigned managed identity
$AzureContext = (Connect-AzAccount -Identity).context

# Set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext

# Get initial domain name or default domain name
$Organization = (Get-AzTenant).Domains | Where-Object { $_ -like "*.onmicrosoft.com" }

if ($null -eq $Organization)
{
    $Organization = (Get-AzTenant).DefaultDomain
}

# Import the ExchangeOnlineManagement Module we imported into the Automation Account
Import-Module ExchangeOnlineManagement

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
