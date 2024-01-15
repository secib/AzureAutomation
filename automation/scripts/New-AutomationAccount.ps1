[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]
    $SubscriptionName,

    [Parameter(Mandatory)]
    [string]
    $ResourceGroupName,

    [Parameter(Mandatory)]
    [string]
    $DeploymentName,

    [Parameter(Mandatory)]
    [string]
    $TemplateFile,

    [Parameter(Mandatory)]
    [string]
    $TemplateParameterFile,

    [Parameter(Mandatory, ParameterSetName = "GrantPermissions")]
    [psobject[]]
    $ApplicationRoleAssignment,

    [Parameter()]
    [SecureString]
    $AccessToken
)

$azContext = Set-AzContext -Subscription $SubscriptionName -ErrorAction Stop

# ARM deployment
$params = @{
    Name                  = $DeploymentName
    ResourceGroupName     = $ResourceGroupName
    TemplateFile          = $TemplateFile
    TemplateParameterFile = $TemplateParameterFile
}

$azResourceGroupDeployment = New-AzResourceGroupDeployment @params -ErrorAction Stop
$azResourceGroupDeployment | Out-Host

if ($PSCmdlet.ParameterSetName -eq "GrantPermissions")
{
    $null = Connect-Graph -AccessToken ((Get-AzAccessToken -ResourceTypeName MSGraph).token)

    # Grant Graph API permissions to automation account
    $managedIdentityId = Get-azAutomationAccount -ResourceGroupName $ResourceGroupName -AutomationAccountName $azResourceGroupDeployment.Outputs["automationAccountName"].Value | Select-Object -ExpandProperty Identity | Select-Object -ExpandProperty PrincipalId

    $servicePrincipal = Get-GraphServicePrincipal | Where-Object { $_.id -eq $managedIdentityId }
    if (!$servicePrincipal) { throw "Service principal '$managedIdentityId' doesn't exist" }

    foreach ($roleAssignment in $ApplicationRoleAssignment)
    {
        # get application whose permissions will be granted
        $resourceServicePrincipal = Get-GraphServicePrincipal -ResourceAppId $roleAssignment.ResourceAppId
        if (!$resourceServicePrincipal) { throw "Resource '$roleAssignment.ResourceAppId' doesn't exist" }

        # grant requested permissions
        foreach ($role in $roleAssignment.ApplicationRole)
        {
            $appRole = $resourceServicePrincipal.appRoles | Where-Object { $_.Value -eq $role -and $_.allowedMemberTypes -contains "Application" }
            if (!$appRole)
            {
                Write-Warning "Application permission '$role' wasn't found in '$($roleAssignment.ResourceAppId)' application. Therefore it cannot be added."
                continue
            }

            $appRoleAssignment = Get-GraphServicePrincipalAppRoleAssignment -ObjectId $managedIdentityId | Where-Object { $_.appRoleId -eq $appRole.id }
            if (!$appRoleAssignment)
            {
                $null = New-GraphServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentityId -ResourceId $resourceServicePrincipal.id -AppRoleId $appRole.id
            }
        }
    }
}

if ($PSBoundParameters.ContainsKey("AccessToken") -and $AccessToken)
{
    $params = @{
        ObjectId           = Get-azAutomationAccount -ResourceGroupName $ResourceGroupName -AutomationAccountName $azResourceGroupDeployment.Outputs["automationAccountName"].Value | Select-Object -ExpandProperty Identity | Select-Object -ExpandProperty PrincipalId
        Scope              = "/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Automation/automationAccounts/{2}" -f $azContext.Subscription.Id, $ResourceGroupName, $azResourceGroupDeployment.Outputs["automationAccountName"].Value
        RoleDefinitionName = "Contributor"
    }

    $roleAssignment = Get-AzRoleAssignment @params

    if ($null -eq $roleAssignment)
    {
        # Grant contributor role to managed identity (required for source control)
        $roleAssignment = New-AzRoleAssignment @params
    }

    $roleAssignment | Out-Host

    # Configure Github as source control
    $sourceControl = $azResourceGroupDeployment.Outputs["sourceControl"].Value.ToString() | ConvertFrom-Json

    $params = @{
        Name                  = $sourceControl.name
        ResourceGroupName     = $ResourceGroupName
        AutomationAccountName = $azResourceGroupDeployment.Outputs["automationAccountName"].Value
    }

    $automationSourceControl = Get-AzAutomationSourceControl @params -ErrorAction SilentlyContinue

    if ($null -eq $automationSourceControl)
    {
        $params = @{
            Name                  = $sourceControl.name
            RepoUrl               = "https://github.com/{0}/{1}.git" -f $sourceControl.repositoryAccountName, $sourceControl.repositoryName
            SourceType            = "GitHub"
            Branch                = $sourceControl.branch
            FolderPath            = $sourceControl.folderPath
            AccessToken           = $AccessToken
            ResourceGroupName     = $ResourceGroupName
            AutomationAccountName = $azResourceGroupDeployment.Outputs["automationAccountName"].Value
            EnableAutoSync        = $true
        }
    
        $automationSourceControl = New-AzAutomationSourceControl @params
    }

    $automationSourceControl | Out-Host
}

return $azResourceGroupDeployment.Outputs