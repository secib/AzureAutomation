[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [object]
    $WebhookData
)

class ConfigurationFile
{
    [AutomationAccountDeploymentBuilder[]]$AutomationAccountDeploymentBuilders
}

class AutomationAccountDeploymentBuilder
{
    [string]$SubscriptionId
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

class AutomationAccountDeploymentOutput
{
    [SourceControlOuput]$SourceControl
    [WebhookOutput[]]$Webhook
    [string]$AutomationAccountName
}

class SourceControlOuput
{
    [string]$Name
    [string]$RepositoryUrl
    [string]$Branch
    [string]$FolderPath
    [string]$SourceType
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

    Write-Output "$((Get-Date).ToString("hh:mm:ss")) - Assignation du rôle 'Contributor' au compte d'automatisation $AutomationAccountName"

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

    Write-Output "$((Get-Date).ToString("hh:mm:ss")) - Configuration du contrôle de source $($SourceControl.Name) pour le compte d'automatisation $AutomationAccountName"

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
            SourceType            = $SourceControl.SourceType
            RepoUrl               = $SourceControl.RepositoryUrl
            Branch                = $SourceControl.Branch
            FolderPath            = $SourceControl.FolderPath
            AccessToken           = Read-Host -AsSecureString -Prompt "PAT"
            EnableAutoSync        = $true
        }

        $automationSourceControl = New-AzAutomationSourceControl @params
    }

    $automationSourceControl | Out-Host
}

function New-ServicePrincipalAppRoleAssignment
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $ServicePrincipalId,
    
        [Parameter(Mandatory)]
        [ApplicationRoleAssignment[]]
        $ApplicationRoleAssignment
    )

    Get-GraphServicePrincipal | Where-Object { $_.servicePrincipalType -eq "ManagedIdentity" }
    $servicePrincipal = Get-GraphServicePrincipal | Where-Object { $_.id -eq $ServicePrincipalId } | Select-Object -First 1
    if (!$servicePrincipal) { throw "Service principal with id '$ServicePrincipalId' not found" }
    
    foreach ($roleAssignment in $ApplicationRoleAssignment)
    {
        # get application whose permissions will be granted
        $resourceServicePrincipal = Get-GraphServicePrincipal -ResourceAppId $roleAssignment.ResourceAppId
        if (!$resourceServicePrincipal) { Write-Error "Service principal with applicationId '$($roleAssignment.ResourceAppId)' not found" }
    
        # grant requested permissions
        foreach ($role in $roleAssignment.ApplicationRoles)
        {
            $appRole = $resourceServicePrincipal.appRoles | Where-Object { $_.Value -eq $role -and $_.allowedMemberTypes -contains "Application" }
            if (!$appRole)
            {
                Write-Warning "Application permission '$role' not found in '$($roleAssignment.ResourceAppId)' application"
                continue
            }
    
            Write-Output "$((Get-Date).ToString("hh:mm:ss")) - Assignation du rôle '$role' au principal de service $ServicePrincipalId"
            $appRoleAssignment = Get-GraphServicePrincipalAppRoleAssignment -ObjectId $ServicePrincipalId | Where-Object { $_.appRoleId -eq $appRole.id }
            if (!$appRoleAssignment)
            {
                $appRoleAssignment = New-GraphServicePrincipalAppRoleAssignment -ServicePrincipalId $ServicePrincipalId -ResourceId $resourceServicePrincipal.id -AppRoleId $appRole.id
            }
            $appRoleAssignment | Out-Host
        }
    }    
}

function New-DirectoryRoleMember
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $ServicePrincipalId,

        [Parameter(Mandatory)]
        [string]
        $DirectoryRoleName
    )

    Write-Output "$((Get-Date).ToString("hh:mm:ss")) - Assignation du rôle d'annuaire '$DirectoryRoleName' au principal de service $ServicePrincipalId"

    $directoryRole = Get-GraphDirectoryRole | Where-Object { $_.displayName -eq $DirectoryRoleName } | Select-Object -First 1
    $roleAssignment = Get-GraphDirectoryRoleMember -id $directoryRole.Id | Where-Object { $_.id -eq $ServicePrincipalId } | Select-Object -First 1    

    if ($null -eq $roleAssignment)
    {
        $null = New-GraphDirectoryRoleMember -DirectoryRoleId $directoryRole.Id -ObjectId $ServicePrincipalId
    }
    
    $roleAssignment | Out-Host
}

function Get-AzToken
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $ResourceUri,
        [Parameter(Mandatory = $false)]
        [String]
        $TenantId,
        [Switch]$AsHeader
    )
    
    $Context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
    if ([string]::IsNullOrEmpty($TenantId))
    {
        $TenantId = $context.Tenant.Id.ToString()
    }
    $Token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $TenantId, $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, $ResourceUri).AccessToken
    if ($AsHeader)
    {
        return @{Headers = @{Authorization = "Bearer $Token" } }
    }
    return $Token
}

# Logic to allow for testing in Test pane
if (-Not $WebhookData.RequestBody)
{ 
    $WebhookData = $WebhookData | ConvertFrom-Json
}

try
{
    [ConfigurationFile]$configurationFile = $WebhookData.RequestBody | ConvertFrom-Json -ErrorAction Stop
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

# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process

# Connect to Azure with system-assigned managed identity 
$null = (Connect-AzAccount -Identity -AccountId "19c3b4b2-26c3-4eca-bfc5-ecb7d5011b2d").context

foreach ($builder in $configurationFile.AutomationAccountDeploymentBuilders)
{
    $subscription = Get-AzSubscription -SubscriptionId $builder.SubscriptionId
    $subscription | Format-List *
    $azContext = Set-AzContext -Subscription $subscription.Id -ErrorAction Stop
    $deploymentOutput = New-ResourceGroupDeployment -Builder $builder.ResourceGroupDeployment -Verbose
    Write-Output $deploymentOutput

    # save webhookUri
    if (!([string]::IsNullOrEmpty($deploymentOutput.Webhook.Uri)))
    {
        Write-Output "$((Get-Date).ToString("hh:mm:ss")) - Sauvegarde de l'uri webhook dans le coffre-fort" -Verbose
        # $deploymentOutput.Webhook.Uri
    }

    # Set automation account source control
    if ($null -ne $deploymentOutput.SourceControl)
    {
        $params = @{
            SourceControl         = $deploymentOutput.SourceControl
            SubscriptionId        = $azContext.Subscription.Id
            ResourceGroupName     = $Builder.ResourceGroupDeployment.ResourceGroupName
            AutomationAccountName = $deploymentOutput.AutomationAccountName
        }

        # Issue with delegation. Condition not recognized
        # $automationSourceControl = New-AutomationSourceControlDeployment @params -Verbose
        # $automationSourceControl | Out-Host
    }

    # Grant account required permissions
    if ($Builder.ApplicationRoleAssignments.Count -gt 0)
    {
        Write-Output $subscription.HomeTenantId
        $accessToken = Get-AzToken -ResourceUri 'https://graph.microsoft.com/' -TenantId $subscription.HomeTenantId
        Write-Output $accessToken
        $null = Connect-Graph -AccessToken $accessToken

        foreach ($assignment in $Builder.ApplicationRoleAssignments)
        {
            $params = @{
                ServicePrincipalId        = Get-azAutomationAccount -ResourceGroupName $Builder.ResourceGroupDeployment.ResourceGroupName -AutomationAccountName $deploymentOutput.AutomationAccountName | Select-Object -ExpandProperty Identity | Select-Object -ExpandProperty PrincipalId
                ApplicationRoleAssignment = $assignment
            }
    
            New-ServicePrincipalAppRoleAssignment @params -Verbose
        }
    }

    #Grant account required directory roles
    if ($Builder.DirectoryRoles.Count -gt 0)
    {
        Write-Output $subscription.HomeTenantId
        $accessToken = Get-AzToken -ResourceUri 'https://graph.microsoft.com/' -TenantId $subscription.HomeTenantId
        Write-Output $accessToken
        $null = Connect-Graph -AccessToken $accessToken
        $managedIdentityId = Get-azAutomationAccount -ResourceGroupName $Builder.ResourceGroupDeployment.ResourceGroupName -AutomationAccountName $deploymentOutput.AutomationAccountName | Select-Object -ExpandProperty Identity | Select-Object -ExpandProperty PrincipalId

        foreach ($directoryRoleName in $Builder.DirectoryRoles)
        {
            New-DirectoryRoleMember -ServicePrincipalId $managedIdentityId -DirectoryRoleName $directoryRoleName -Verbose
        }
    }    
}
