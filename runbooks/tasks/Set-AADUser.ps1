[CmdletBinding()]
param (
    [Parameter()]
    [object]
    $WebhookData
)

class Body
{
    [string]$ObjectId
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
    $WebhookData =  $WebhookData | ConvertFrom-Json
}

[Body]$requestBody = $WebhookData.RequestBody | ConvertFrom-Json
if ($null -eq $requestBody)
{
    Write-Error "Unexpected request body."
}

$azProfile = Connect-AzAccount -Identity -ErrorAction Stop

$targetUser = Get-AzADUser -ObjectId $requestBody.ObjectId

if ($null -eq $targetUser)
{
    Write-Error "User with objectId $($requestBody.ObjectId) not found."
    exit
}

Write-Output $targetUser
# Update-AzADUser -ObjectId $requestBody.ObjectId -UsageLocation "fr"