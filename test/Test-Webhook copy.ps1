$webhookURI = "https://cb632b6a-8bb5-443c-a57e-436fc74422e1.webhook.fc.azure-automation.net/webhooks?token=JR1oJRuyiTPMB2nyVFfTTr7WGylRXUV31zBkV8Ibw4w%3d"
$body = '{"AutomationAccountDeploymentBuilders":[{"SubscriptionId":"ffb58682-139a-41b1-b4b3-20fa17ed741c","ResourceGroupDeployment":{"ResourceGroupName":"Automation","TemplateUri":"https://raw.githubusercontent.com/secib/AzureAutomation/main/automation/accounts/AdministrativeTask/templates/armTemplate_administrativeTask.json","TemplateParameterUri":"https://raw.githubusercontent.com/secib/AzureAutomation/main/automation/accounts/AdministrativeTask/templates/armTemplate_administrativeTask.parameters.json"},"ApplicationRoleAssignments":[{"ResourceAppId":"00000003-0000-0000-c000-000000000000","ApplicationRoles":["User.ReadWrite.All"]}],"DirectoryRoles":[]},{"SubscriptionId":"ffb58682-139a-41b1-b4b3-20fa17ed741c","ResourceGroupDeployment":{"ResourceGroupName":"Automation","TemplateUri":"https://raw.githubusercontent.com/secib/AzureAutomation/main/automation/accounts/Baseline/templates/baseline.json","TemplateParameterUri":"https://raw.githubusercontent.com/secib/AzureAutomation/main/automation/accounts/Baseline/templates/baseline.parameters.json"},"ApplicationRoleAssignments":[{"ResourceAppId":"00000002-0000-0ff1-ce00-000000000000","ApplicationRoles":["Exchange.ManageAsApp"]}],"DirectoryRoles":["Exchange Administrator"]}]}'

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
