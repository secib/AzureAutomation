$automationAccount = "AdministrativeTask"
$resourceGroup = "Automation"
$webhookURI = "https://80d4512e-8d97-4a5b-85ea-e36a72d06e84.webhook.fc.azure-automation.net/webhooks?token=pV5k%2bd85H3UHlI34xCr7QXElwcZhuJRC1etwp3l2%2fcg%3d"
$body = @{"objectId" = "eacf123d-c8ca-4ae1-8a51-19be3b488928" } | ConvertTo-Json -Compress

$responseFile = Invoke-WebRequest -Method Post -Uri $webhookURI -Body $body -UseBasicParsing
$responseFile

#isolate job ID
$jobid = (ConvertFrom-Json ($responseFile.Content)).jobids[0]

# Get output
Get-AzAutomationJobOutput `
    -AutomationAccountName $automationAccount `
    -Id $jobid `
    -ResourceGroupName $resourceGroup `
    -Stream Output

Get-AzAutomationJob `
    -AutomationAccountName $automationAccount `
    -Id $jobid `
    -ResourceGroupName $resourceGroup `
