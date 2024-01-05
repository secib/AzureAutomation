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
    exit
}

# Logic to allow for testing in Test pane
if (-Not $WebhookData.RequestBody)
{ 
    $WebhookData = (ConvertFrom-Json -InputObject $WebhookData)
}

$azProfile = Connect-AzAccount -Identity -ErrorAction Stop

Write-Output $WebhookData.RequestBody
$requestBody = (ConvertFrom-Json -InputObject $WebhookData.RequestBody)
$objectId = $requestBody.objectId
$targetUser = Get-AzADUser -ObjectId $objectId

if ($null -eq $targetUser)
{
    Write-Error "User with objectId $objectId not found."
    exit
}

# Update-AzADUser -ObjectId $objectId -UsageLocation "fr"