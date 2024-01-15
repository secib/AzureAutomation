[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]
    $KeyVaultName = "SecibWebtools-Keyvault",

    [Parameter(Mandatory = $false)]
    [string]
    $ToEmail = "SecibToolsAPIAdministrator@septeogroup.onmicrosoft.com",

    [Parameter(Mandatory = $false)]
    [string]
    $LogicAppUri = "https://prod-08.francecentral.logic.azure.com:443/workflows/5cca1485e6ff4a79a0ba74a7abfb9e99/triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=xNIMwHVJu6B1PzYsqgYjBdtsGcBUOM3Qo9wHY0KCLZI",

    [Parameter(Mandatory = $false)]
    [string]
    $DownloadUrl = "https://secibwebtools.blob.core.windows.net/tools/SecibAdminToolkit.zip",

    [Parameter(Mandatory = $false)]
    [string]
    $DocumentUrl = "https://septeogroup.sharepoint.com/:w:/s/Intune/EYZTKPLONlBIgsmydeCg-d0BMndPLW2Y5xu1UsgTfsGirQ?e=rFWYx4",

    [Parameter(Mandatory = $false)]
    [int[]]
    $NumberOfDaysBeforeExpirationList = (30, 21, 14, 7, 3, 2, 1)
)

function Main
{
    "Logging in to Azure..."
    $azProfile = Connect-AzAccount -Identity -ErrorAction Stop
    # $azProfile = Connect-AzAccount -ErrorAction Stop

    $secretCollection = Get-AzKeyVaultSecret -VaultName $KeyVaultName | `
        Where-Object { $_.Expires } | `
        Where-Object { $numberOfDaysBeforeExpirationList -contains [SecretNotificationHandler]::GetDaysBeforeExpiration($_) -or [SecretNotificationHandler]::GetSecretState($_) -eq [KeyVaultSecretState]::Expired }

    if ($secretCollection.Count -eq 0)
    {
        Write-Output "Secrets are up to date."
    }
    else
    {
        $secretNotificationCollection = [System.Collections.Generic.List[SecretNotification]]::new()

        foreach ($secret in $secretCollection)
        {
            $secretNotificationCollection.Add(
                [SecretNotification]@{
                    Name                 = $secret.Name
                    ExpirationDate       = $secret.Expires
                    VaultName            = $secret.VaultName
                    State                = [SecretNotificationHandler]::GetSecretState($secret)
                    DaysBeforeExpiration = [SecretNotificationHandler]::GetDaysBeforeExpiration($secret)
                }) | Out-Null
        }

        Write-Output "Following secrets will expire soon."
        Write-Output $secretNotificationCollection

        $params = @{
            Subject      = "Azure KeyVault Notification"
            ToEmail      = $ToEmail
            MailBody     = [MailBuilder]::CreateMailBody([MailBody]::new($secretNotificationCollection, $DownloadUrl, $DocumentUrl))
            Attachements = [MailBuilder]::CreateMailAttachement($secretCollection, $azProfile.Context.Tenant.Id)
            Uri          = $LogicAppUri
        }

        Send-Mail @params
    }
}

function Send-Mail
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Subject,

        [Parameter(Mandatory = $true)]
        [string]$ToEmail,

        [Parameter(Mandatory = $true)]
        [string]$MailBody,

        [Parameter(Mandatory = $false)]
        [Attachement[]]$Attachements,

        [Parameter(Mandatory = $true)]
        [string]$Uri
    )

    $bodyRequest = [PSCustomObject]@{
        email        = $ToEmail
        subject      = $Subject
        body         = $MailBody
        attachements = $Attachements
    }

    $request = @{
        Method      = 'POST'
        ContentType = "application/json"
        Body        = $bodyRequest | ConvertTo-Json
        Uri         = $Uri
    }

    Invoke-Restmethod @request
}

class SecretNotificationHandler
{
    [int] static GetDaysBeforeExpiration([PsCustomObject]$item)
    {
        return [math]::max(0, ($item.Expires - (Get-Date)).Days)
    }

    [KeyVaultSecretState] static GetSecretState([PsCustomObject]$item)
    {
        if ([SecretNotificationHandler]::GetDaysBeforeExpiration($item) -eq 0)
        {
            return [KeyVaultSecretState]::Expired
        }
        else
        {
            return [KeyVaultSecretState]::Active
        }
    }
}

class MailBody
{
    [System.Collections.Generic.List[SecretNotification]]$NotificationCollection
    [string]$ArchiveUrl
    [string]$DocumentUrl

    MailBody([System.Collections.Generic.List[SecretNotification]]$notificationCollection, [string]$archiveUrl, [string]$documentUrl)
    {
        $this.NotificationCollection = $notificationCollection
        $this.ArchiveUrl = $archiveUrl
        $this.DocumentUrl = $documentUrl
    }
}

class MailBuilder
{
    [string] static CreateMailBody([MailBody]$mailBody)
    {
        $secretNotificationCollectionHtml = $mailBody.NotificationCollection | ConvertTo-Html -As List -Property Name, VaultName, ExpirationDate, State, DaysBeforeExpiration -Fragment
        $secretNotificationCollectionHtml = $secretNotificationCollectionHtml -replace '<td>Active</td>', '<td class="ActiveStatus">Active</td>'
        $secretNotificationCollectionHtml = $secretNotificationCollectionHtml -replace '<td>Expired</td>', '<td class="ExpiredStatus">Expired</td>'

        $title = "<h1>Azure KeyVault Notification</h1>"
        $body = @'
        <h2>Pour renouveler un secret:</h2>
        <ol>
            <li>T&#233;l&#233;charger et extraire l'archive <a href="{1}">SecibAdminToolkit</a></li>
            <li>Enregistrer localement le fichier csv en pi&#232ce jointe</li>
            <li>Ex&#233;cuter manuellement le script <b>Register-PartnerCenterApplicationCredentials.ps1</b></li>
        </ol>

        Pour plus d'informations, consulter la documentation <a href="{0}">Secib Tools API</a>.
'@ -f $mailBody.DocumentUrl, $mailBody.ArchiveUrl
        $head = @"
        <style>

            h1 {
                font-family: Arial, Helvetica, sans-serif;
                color: #000099;
                font-size: 28px;
            }

            h2 {
                font-family: Arial, Helvetica, sans-serif;
                color: #000099;
                font-size: 16px;
            }

            table {
                font-size: 12px;
                border: 0px;
                font-family: Arial, Helvetica, sans-serif;
            }

            td {
                padding: 4px;
                margin: 0px;
                border: 0;
            }

            th {
                background: #395870;
                background: linear-gradient(#49708f, #293f50);
                color: #fff;
                font-size: 11px;
                text-transform: uppercase;
                padding: 10px 15px;
                vertical-align: middle;
            }

            tbody tr:nth-child(even) {
                background: #f0f0f2;
            }

            .ActiveStatus {
                color: #008000;
            }

            .ExpiredStatus {
                color: #ff0000;
            }

            </style>
"@

        return ConvertTo-HTML -Body "$title $secretNotificationCollectionHtml $body" -Head $head
    }

    [System.Collections.Generic.List[Attachement]] static CreateMailAttachement([System.Collections.Generic.List[PsCustomObject]]$secretCollection, [string]$tenantId)
    {
        $attachements = [System.Collections.Generic.List[Attachement]]::new()

        foreach ($secret in $secretCollection)
        {
            $secretConfiguration = [SecretConfiguration]@{
                SecretName         = $secret.Name
                VaultName          = $secret.VaultName
                TenantId           = $tenantId
                ApplicationId      = $secret.Tags["ApplicationId"]
                SecretType         = $secret.Tags["SecretType"]
                AuthenticationFlow = $secret.Tags["AuthenticationFlow"]
            }

            $secretConfigurationString = ($secretConfiguration | ConvertTo-Csv -NoTypeInformation -Delimiter ";") -join "`n"

            $attachements.Add([Attachement]@{
                    Name         = "$($secret.Name).csv"
                    ContentBytes = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($secretConfigurationString))
                })
        }

        return $attachements
    }
}

enum KeyVaultSecretState
{
    Active
    Expired
}

class SecretNotification
{
    [string]$Name
    [string]$VaultName
    [KeyVaultSecretState]$State
    [DateTime]$ExpirationDate
    [int]$DaysBeforeExpiration
}

enum SecretType
{
    ClientSecret
    RefreshToken
}

enum AuthenticationFlow
{
    AuthorizationCode
    DeviceCode
}

class SecretConfiguration
{
    [string]$SecretName
    [string]$VaultName
    [string]$TenantId
    [string]$ApplicationId
    [Nullable[SecretType]]$SecretType
    [Nullable[AuthenticationFlow]]$AuthenticationFlow
}

class Attachement
{
    [string]$Name
    [string]$ContentBytes
}

. Main
