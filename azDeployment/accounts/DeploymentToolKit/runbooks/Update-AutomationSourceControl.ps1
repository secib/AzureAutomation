param (
    [Parameter (Mandatory = $false)]
    [object]$WebHookData
)



# If runbook was called from Webhook, WebhookData will not be null.
if ($null -ne $WebHookData)
{
    # Logic to allow for testing in Test pane
    if (-Not $WebhookData.RequestBody)
    { 
        $WebhookData = $WebhookData | ConvertFrom-Json
    }

    # Header message passed as a hashtable 
    Write-Output "The Webhook Header"
    Write-Output $WebHookData.RequestHeader

    # This is the name of the webhook when configured in Azure Automation
    Write-Output 'The Webhook Name'
    Write-Output $WebHookData.WebhookName

    # Body of the message.
    Write-Output 'The Request Body'
    Write-Output $WebHookData.RequestBody

    Write-Output 'X-Hub-Signature-256'
    Write-Output $WebHookData.RequestHeader.'X-Hub-Signature-256'
}
else
{
    Write-Error "Runbook mean to be started only from webhook." 
}

