[CmdletBinding()]
param (
    [Parameter()]
    [object]
    $WebhookData
)

class WebhookRequestBody
{
    [string]$SubscriptionId
    [AutomationAccountDeploymentBuilder]$TemplateObject
}

class AutomationAccountDeploymentBuilder
{
    [string]$SubscriptionName
    [ResourceGroupDeployment]$ResourceGroupDeployment
    [ApplicationRoleAssignment[]]$ApplicationRoleAssignments
    [string[]]$DirectoryRoles
}

class ResourceGroupDeployment
{
    [string]$ResourceGroupName
    [string]$TemplateUri
    [string]$TemplateParameterUri
}

class ApplicationRoleAssignment
{
    [string]$ResourceAppId
    [string[]]$ApplicationRoles
}

class AutomationSourceControlDeploymentBuilder
{
    [string]$Name
    [string]$RepoUrl
    [string]$SourceType
    [string]$Branch
    [string]$FolderPath
    [securestring]$AccessToken
    [string]$ResourceGroupName
    [string]$AutomationAccountName
    [bool]$EnableAutoSync
}

class AutomationAccountDeploymentOutput
{
    [SourceControlOuput]$SourceControl
    [WebhookOutput]$Webhook
    [string]$AutomationAccountName
}

class SourceControlOuput
{
    [string]$Name
    [string]$RepositoryAccountName
    [string]$RepositoryName
    [string]$Branch
    [string]$FolderPath
    [string]$RawBaseUri
}

class WebhookOutput
{
    [string]$ResourceGroupName
    [string]$AutomationAccountName
    [string]$Name
    [string]$Uri
    [string]$CreationTime
    [string]$ExpiryTime
    [string]$LastModifiedTime
}

function New-ResourceGroupDeployment
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ResourceGroupDeployment]
        $Builder
    )    

    $params = @{
        Name = (Get-Date).ToString("yyyyMMddhhmmss")
    }
    $Builder.psobject.properties | ForEach-Object { $params[$_.Name] = $_.Value }
    $azResourceGroupDeployment = New-AzResourceGroupDeployment @params -ErrorAction Stop
    $azResourceGroupDeployment | Out-Host
    
    return [AutomationAccountDeploymentOutput]@{
        AutomationAccountName = $azResourceGroupDeployment.Outputs["automationAccountName"].Value
        SourceControl         = $azResourceGroupDeployment.Outputs["sourceControl"].Value.ToObject("SourceControlOuput")
        Webhook               = $azResourceGroupDeployment.Outputs["webhook"].Value.ToObject("WebhookOutput")
    }
}

function New-AutomationSourceControlDeployment
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [SourceControlOuput]
        $SourceControl,

        [Parameter(Mandatory)]
        [string]
        $SubscriptionId,

        [Parameter(Mandatory)]
        [string]
        $ResourceGroupName,

        [Parameter(Mandatory)]
        [string]
        $AutomationAccountName
    )

    Write-Verbose "$((Get-Date).ToString("hh:mm:ss")) - Assignation du rôle 'Contributor' au compte d'automatisation $AutomationAccountName"

    $params = @{
        ObjectId           = Get-azAutomationAccount -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName | Select-Object -ExpandProperty Identity | Select-Object -ExpandProperty PrincipalId
        Scope              = "/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Automation/automationAccounts/{2}" -f $SubscriptionId, $ResourceGroupName, $AutomationAccountName
        RoleDefinitionName = "Contributor"
    }

    $roleAssignment = Get-AzRoleAssignment @params

    if ($null -eq $roleAssignment)
    {
        # Grant contributor role to managed identity (required for source control)
        $roleAssignment = New-AzRoleAssignment @params
    }

    $roleAssignment | Out-Host

    Write-Verbose "$((Get-Date).ToString("hh:mm:ss")) - Configuration du contrôle de source $($SourceControl.Name) pour le compte d'automatisation $AutomationAccountName"

    $params = @{
        Name                  = $SourceControl.Name
        ResourceGroupName     = $ResourceGroupName
        AutomationAccountName = $AutomationAccountName
    }

    $automationSourceControl = Get-AzAutomationSourceControl @params -ErrorAction SilentlyContinue

    if ($null -eq $automationSourceControl)
    {
        $params = @{
            Name                  = $SourceControl.Name
            ResourceGroupName     = $ResourceGroupName
            AutomationAccountName = $AutomationAccountName
            SourceType            = "VsoGit"
            RepoUrl               = "https://dev.azure.com/{0}/{1}/_git/{2}" -f "AzDeploymentToolkitTestProject", "AzDeploymentToolKitTest", "AzDeploymentToolKitTest"
            Branch                = $SourceControl.Branch
            FolderPath            = $SourceControl.FolderPath
            AccessToken           = (Get-AzKeyVaultSecret -VaultName 'AzAutomation-Keyvault' -Name 'Ado-PAT-SourceControl').SecretValue
            EnableAutoSync        = $true
        }

        $automationSourceControl = New-AzAutomationSourceControl @params
    }

    $automationSourceControl | Out-Host
}

function Publish-AzAutomationAccount
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $SubscriptionId,

        [Parameter(Mandatory)]
        [AutomationAccountDeploymentBuilder]
        $TemplateObject
    )

    $deploymentOutput = New-ResourceGroupDeployment -Builder $TemplateObject.ResourceGroupDeployment -Verbose
    $deploymentOutput.Webhook | Out-Host

    # save webhookUri
    if (!([string]::IsNullOrEmpty($deploymentOutput.Webhook.Uri)))
    {
        Write-Verbose "$((Get-Date).ToString("hh:mm:ss")) - Sauvegarde de l'uri webhook dans le coffre-fort" -Verbose
        # $deploymentOutput.Webhook.Uri
    }

    # Set automation account source control
    if ($null -ne $deploymentOutput.SourceControl)
    {
        $params = @{
            SourceControl         = $deploymentOutput.SourceControl
            SubscriptionId        = $SubscriptionId
            ResourceGroupName     = $TemplateObject.ResourceGroupDeployment.ResourceGroupName
            AutomationAccountName = $deploymentOutput.AutomationAccountName
        }
    
        $automationSourceControl = New-AutomationSourceControlDeployment @params -Verbose
        $automationSourceControl | Out-Host
    }

    # Grant account required permissions
    if ($Builder.ApplicationRoleAssignments.Count -gt 0)
    {
        foreach ($assignment in $Builder.ApplicationRoleAssignments)
        {
            $params = @{
                ServicePrincipalId        = Get-azAutomationAccount -ResourceGroupName $TemplateObject.ResourceGroupDeployment.ResourceGroupName -AutomationAccountName $deploymentOutput.AutomationAccountName | Select-Object -ExpandProperty Identity | Select-Object -ExpandProperty PrincipalId
                ApplicationRoleAssignment = $assignment
            }
        
            New-ServicePrincipalAppRoleAssignment @params -Verbose
        }
    }
    
    #Grant account required directory roles
    if ($Builder.DirectoryRoles.Count -gt 0)
    {
        $managedIdentityId = Get-azAutomationAccount -ResourceGroupName $TemplateObject.ResourceGroupDeployment.ResourceGroupName -AutomationAccountName $deploymentOutput.AutomationAccountName | Select-Object -ExpandProperty Identity | Select-Object -ExpandProperty PrincipalId
    
        foreach ($directoryRoleName in $Builder.DirectoryRoles)
        {
            New-DirectoryRoleMember -ServicePrincipalId $managedIdentityId -DirectoryRoleName $directoryRoleName -Verbose
        }
    }
}

Import-Module Graph

# Logic to allow for testing in Test pane
if (-Not $WebhookData.RequestBody)
{ 
    $WebhookData = $WebhookData | ConvertFrom-Json
}

try
{
    [WebhookRequestBody]$requestBody = $WebhookData.RequestBody | ConvertFrom-Json -ErrorAction Stop
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

$null = Connect-AzAccount -Identity -ErrorAction Stop
$subscription = Get-AzSubscription -SubscriptionId $requestBody.SubscriptionId
$azContext = Set-AzContext -Subscription $subscription.Id -ErrorAction Stop
$null = Connect-Graph -AccessToken ((Get-AzAccessToken -ResourceTypeName MSGraph -TenantId $subscription.HomeTenantId ).token)

Publish-AzAutomationAccount -SubscriptionId $requestBody.subscriptionId -TemplateObject $requestBody.TemplateObject