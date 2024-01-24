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

$azProfile = Connect-AzAccount -Identity -ErrorAction Stop

$targetUser = Get-AzADUser -ObjectId $requestBody.ObjectId

if ($null -eq $targetUser)
{
    Write-Error "User with objectId $($requestBody.ObjectId) not found."
    exit
}

$params = @{
    ObjectId       = $requestBody.ObjectId
    UsageLocation  = "fr"
    PasswordPolicy = "DisablePasswordExpiration"
}

Update-AzADUser @params

Write-Output $targetUser

# commentaire
