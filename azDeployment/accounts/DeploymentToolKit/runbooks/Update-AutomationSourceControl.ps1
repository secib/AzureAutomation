[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $SubscriptionName,

    [Parameter()]
    [string]
    $ResourceGroupName,

    [Parameter()]
    [string]
    $AutomationAccountName,
    
    [Parameter()]
    [string]
    $SourceControlName,

    [Parameter()]
    [string]
    $AccessToken
)

$null = Set-AzContext -Subscription $SubscriptionName -ErrorAction Stop

$secureAccessToken = ConvertTo-SecureString -String $AccessToken -AsPlainText -Force
Get-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $SourceControlName | Update-AzAutomationSourceControl -AccessToken $secureAccessToken
#