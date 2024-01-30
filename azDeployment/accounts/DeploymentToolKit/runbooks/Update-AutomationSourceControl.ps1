param (
    [Parameter (Mandatory = $false)]
    [object]$WebHookData,

    [Parameter (Mandatory = $false)]
    [string]$ResourceGroupName = "Automation",

    [Parameter (Mandatory = $false)]
    [string]$VaultName = "AzDeploymentToolkit",

    [Parameter (Mandatory = $false)]
    [string]$SecretName = "WebhookPayloadValidationToken"
)

function Get-HMACHash
{
    [CmdletBinding()]
    param (
        # Message to geneate a HMAC hash for
        [Parameter(Mandatory = $true,
            Position = 0,
            ParameterSetName = "Default",
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Message,
        # Secret Key
        [Parameter(Mandatory = $true,
            Position = 1,
            ParameterSetName = "Default",
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("Key")]
        [String]
        $Secret,
        # Algorithm
        [Parameter(Mandatory = $false,
            Position = 2,
            ParameterSetName = "Default",
            ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("MD5", "SHA1", "SHA256", "SHA384", "SHA512")]
        [Alias("alg")]
        [String]
        $Algorithm = "SHA256",
        # Output Format
        [Parameter(Mandatory = $false,
            Position = 2,
            ParameterSetName = "Default",
            ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("Base64", "HEX", "hexlower")]
        [String]
        $Format = "Base64"
    )


    $hmac = switch ($Algorithm)
    {
        "MD5" { New-Object System.Security.Cryptography.HMACMD5; break }
        "SHA1" { New-Object System.Security.Cryptography.HMACSHA1; break }
        "SHA256" { New-Object System.Security.Cryptography.HMACSHA256; break }
        "SHA384" { New-Object System.Security.Cryptography.HMACSHA384; break }
        "SHA512" { New-Object System.Security.Cryptography.HMACSHA512; break }
    }

    $hmac.key = [Text.Encoding]::UTF8.GetBytes($secret)
    $signature = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($message))

    $signature = switch ($Format)
    {
        "HEX" { ($signature | ForEach-Object ToString X2 ) -join '' }
        "hexlower" { ($signature | ForEach-Object ToString x2 ) -join '' }
        Default { [Convert]::ToBase64String($signature) }
    }
   
    return ($signature)
}

function Get-FolderPathFromGitPushEvent
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Body
    )

    $object = $Body | ConvertFrom-Json
    return , ($object.commits.modified | ForEach-Object { $_.Substring(0, $_.lastIndexOf('/')) } | Sort-Object -Unique)
}

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

    # Validating webhook deliveries
    # The hash signature always starts with sha256=
    Write-Output 'X-Hub-Signature-256'
    Write-Output $WebHookData.RequestHeader.'X-Hub-Signature-256'

    # Ensures you do not inherit an AzContext in your runbook
    $null = Disable-AzContextAutosave -Scope Process

    # Connect to Azure with system-assigned managed identity 
    $null = (Connect-AzAccount -Identity).context

    # Get webhook payload validation secret from keyvault
    $secret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName -AsPlainText -ErrorAction Stop

    # Get HMAC hash from the request body and secret
    $hash = Get-HMACHash -Format HEX -Algorithm SHA256 -Message $WebHookData.RequestBody -Secret $secret
    Write-Output 'HMAC Hash'
    Write-Output "sha256=$hash"

    if ($WebHookData.RequestHeader.'X-Hub-Signature-256' -ne "sha256=$hash")
    {
        Write-Error "The webhook payload validation failed"  
    }
    else
    {
        Write-Output "The webhook payload validation succeed"
        $folderPath = Get-FolderPathFromGitPushEvent -Body $WebHookData.RequestBody

        [array]$managedSubscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" -and $_.ManagedByTenantIds }
        Write-Output "Found $($managedSubscriptions.Count) managed suscriptions"

        foreach ($subscription in $managedSubscriptions)
        {
            Write-Output "TenantId $($subscription.HomeTenantId) - Subscription $($subscription.Id)"
            $null = Set-AzContext -Subscription $subscription.Id -ErrorAction Stop
            foreach ($path in $folderPath)
            {
                Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName | Get-AzAutomationSourceControl | Where-Object { $_.FolderPath -match $path } | Start-AzAutomationSourceControlSyncJob            
            }
        }
    }
}
else
{
    Write-Error "Runbook mean to be started only from webhook." 
}
