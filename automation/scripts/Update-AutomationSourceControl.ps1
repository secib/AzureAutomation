[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $TenantId = "4ce0fbf0-7081-4c8c-b135-3ce1152dca0b",

    [Parameter()]
    [string]
    $CertificateThumbprint = "23CA0A6B24E5C120D3C753B29826576111F96CD6",

    [Parameter()]
    [string]
    $SubscriptionName = "Crayon",

    [Parameter()]
    [string]
    $ResourceGroupName = "Automation",

    [Parameter()]
    [string]
    $AutomationAccountName = "AdministrativeTask",
    
    [Parameter()]
    [string]
    $SourceControlName = "SCGitHub",

    [Parameter()]
    [string]
    $AccessToken = "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"
)

$params = @{
    ApplicationId         = "0dd78a24-5595-47bc-be51-0892f839eb7a"
    TenantId              = $TenantId
    ServicePrincipal      = $true
}

$azContext = Set-AzContext -Subscription $SubscriptionName -ErrorAction Stop

$secureAccessToken = ConvertTo-SecureString -String $AccessToken -AsPlainText -Force
Get-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $SourceControlName | Update-AzAutomationSourceControl -AccessToken $secureAccessToken
