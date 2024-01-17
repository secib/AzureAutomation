class ConfigurationFile
{
    [string]$ApplicationId
    [AutomationAccountDeploymentBuilder[]]$AutomationAccountDeploymentBuilders
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
    [string]$TemplateFile
    [string]$TemplateParameterFile
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
    [string]$WebhookUri
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
        WebhookUri            = $azResourceGroupDeployment.Outputs["webhookUri"].Value
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
            SourceType            = "GitHub"
            RepoUrl               = "https://github.com/{0}/{1}.git" -f $SourceControl.RepositoryAccountName, $SourceControl.RepositoryName
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
    
    $servicePrincipal = Get-GraphServicePrincipal | Where-Object { $_.id -eq $ServicePrincipalId } | Select-Object -First 1
    if (!$servicePrincipal) { throw "Service principal with id '$ServicePrincipalId' not found" }
    
    foreach ($roleAssignment in $ApplicationRoleAssignment)
    {
        # get application whose permissions will be granted
        $resourceServicePrincipal = Get-GraphServicePrincipal -ResourceAppId $roleAssignment.ResourceAppId
        if (!$resourceServicePrincipal) { throw "Service principal with applicationId '$($roleAssignment.ResourceAppId)' not found" }
    
        # grant requested permissions
        foreach ($role in $roleAssignment.ApplicationRoles)
        {
            $appRole = $resourceServicePrincipal.appRoles | Where-Object { $_.Value -eq $role -and $_.allowedMemberTypes -contains "Application" }
            if (!$appRole)
            {
                Write-Warning "Application permission '$role' not found in '$($roleAssignment.ResourceAppId)' application"
                continue
            }
    
            Write-Verbose "$((Get-Date).ToString("hh:mm:ss")) - Assignation du rôle '$role' au principal de service $ServicePrincipalId"
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

    $directoryRole = Get-GraphDirectoryRole | Where-Object { $_.displayName -eq $DirectoryRoleName } | Select-Object -First 1
    $roleAssignment = Get-GraphDirectoryRoleMember -id $directoryRole.Id | Where-Object { $_.id -eq $ServicePrincipalId } | Select-Object -First 1
    
    Write-Verbose "$((Get-Date).ToString("hh:mm:ss")) - Assignation du rôle d'annuaire '$DirectoryRoleName' au principal de service $ServicePrincipalId"

    if ($null -eq $roleAssignment)
    {
        $null = New-GraphDirectoryRoleMember -DirectoryRoleId $directoryRole.Id -ObjectId $ServicePrincipalId
    }
    
    $roleAssignment | Out-Host
}

function Start-AzAutomationDeployment
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Path
    )

    [ConfigurationFile]$configurationFile = Get-Content -Encoding UTF8 -Raw -Path $Path | ConvertFrom-Json -ErrorAction Stop

    foreach ($builder in $configurationFile.AutomationAccountDeploymentBuilders)
    {
        $azContext = Set-AzContext -Subscription $builder.SubscriptionName -ErrorAction Stop

        $deploymentOutput = New-ResourceGroupDeployment -Builder $builder.ResourceGroupDeployment -Verbose

        # save webhookUri
        Write-Verbose "$((Get-Date).ToString("hh:mm:ss")) - Ajout de l'uri webhook dans le coffre-fort"
        $deploymentOutput.WebhookUri

        # Set automation account source control
        if ($null -ne $deploymentOutput.SourceControl)
        {
            $params = @{
                SourceControl         = $deploymentOutput.SourceControl
                SubscriptionId        = $azContext.Subscription.Id
                ResourceGroupName     = $Builder.ResourceGroupDeployment.ResourceGroupName
                AutomationAccountName = $deploymentOutput.AutomationAccountName
            }
    
            $automationSourceControl = New-AutomationSourceControlDeployment @params -Verbose
            $automationSourceControl | Out-Host
        }

        # Grant account required permissions
        if ($Builder.ApplicationRoleAssignments.Count -gt 0)
        {
            $null = Connect-Graph -AccessToken ((Get-AzAccessToken -ResourceTypeName MSGraph).token)
    
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
            $null = Connect-Graph -AccessToken ((Get-AzAccessToken -ResourceTypeName MSGraph).token)
            $managedIdentityId = Get-azAutomationAccount -ResourceGroupName $Builder.ResourceGroupDeployment.ResourceGroupName -AutomationAccountName $deploymentOutput.AutomationAccountName | Select-Object -ExpandProperty Identity | Select-Object -ExpandProperty PrincipalId
    
            foreach ($directoryRoleName in $Builder.DirectoryRoles)
            {
                New-DirectoryRoleMember -ServicePrincipalId $managedIdentityId -DirectoryRoleName $directoryRoleName -Verbose
            }
        }    
    }
}

$null = Connect-AzAccount -ErrorAction Stop -WarningAction SilentlyContinue

Start-AzAutomationDeployment -Path (Join-Path $PSScriptRoot "AzAutomationDeployment.parameters.json")
