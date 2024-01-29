param (
    [Parameter (Mandatory = $true)]
    [object]$WebHookData
)

# Logic to allow for testing in Test pane
if (-Not $WebhookData.RequestBody)
{ 
    $WebhookData = $WebhookData | ConvertFrom-Json
}

if ($WebHookData)
{
    # Header message passed as a hashtable 
    Write-Output "The Webhook Header Message"
    Write-Output $WebHookData.RequestHeader.Message

    # This is the name of the webhook when configured in Azure Automation
    Write-Output 'The Webhook Name'
    Write-Output $WebHookData.WebhookName

    # Body of the message.
    Write-Output 'The Request Body'
    Write-Output $WebHookData.RequestBody
}
else
{
    Write-Output 'No data received'
}