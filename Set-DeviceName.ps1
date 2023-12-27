[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $DeviceNamePattern = '^AZ[0-9]{6}-[0-9]{3}$'
)

# get authentication token
function Get-AuthToken
{
    try
    {
        # obtain AccessToken for Microsoft Graph via the managed identity
        $ResourceURL = "https://graph.microsoft.com"
        $Response = [System.Text.Encoding]::Default.GetString((Invoke-WebRequest -UseBasicParsing -Uri "$($env:IDENTITY_ENDPOINT)?resource=$resourceURL" -Method 'GET' -Headers @{'X-IDENTITY-HEADER' = "$env:IDENTITY_HEADER"; 'Metadata' = 'True' }).RawContentStream.ToArray()) | ConvertFrom-Json

        # construct AuthHeader
        $AuthHeader = @{
            'Content-Type'  = 'application/json'
            'Authorization' = "Bearer " + $Response.access_token
        }
    }
    catch
    {
        throw $_
    }
    return $authHeader
}

function ConvertFrom-AutopilotDeviceNameTemplate
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]
        $Name
    )
    
    begin
    {
        $templates = @(
            @{ currentValue = '%RAND:(?<content>.*)%'; newValue = '{{rand:(?<content>.*)}}' },
            @{ currentValue = '%SERIAL%'; newValue = '{{serial}}' }
        )
    }
    process
    {
        $correctDeviceName = $Name    
        
        foreach ($template in $templates)
        {
            if ($Name -match $template.currentValue)
            {
                $prefixDeviceName = $Name.Replace($matches[0], "")
                $suffixDeviceName = $template.newValue.Replace('(?<content>.*)', $matches['content'])
                $correctDeviceName = $prefixDeviceName + $suffixDeviceName
            }
        }
        
        return $correctDeviceName
    }
}

$header = Get-AuthToken

$managedDeviceList = $null
$uri = 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$filter=startswith(operatingSystem,''Windows'')'
$managedDeviceList = (Invoke-RestMethod -Uri $uri -Headers $header -ErrorAction Stop).value

$autopilotDeviceNameTemplate = $null
$uri = 'https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles'
$autopilotDeviceNameTemplate = (Invoke-RestMethod -Uri $uri -Headers $header -ErrorAction Stop).value | Where-Object { $_.displayName -eq 'Autopilot' } | Select-Object -ExpandProperty deviceNameTemplate

if ($null -eq $autopilotDeviceNameTemplate)
{
    Write-Output "Autopilot device name template not found."
    continue
}

foreach ($device in $managedDeviceList)
{
    $currentDeviceName = $device.deviceName
    $deviceID = $device.id

    if ($device.model -like "Cloud PC*")
    {
        Write-Output "Device $currentDeviceName is a Cloud PC. Skipping"
        continue
    }

    if ($currentDeviceName -match $DeviceNamePattern)
    {
        Write-Output "Device $currentDeviceName match $DeviceNamePattern. Skipping"
    }
    else
    {
        $newDeviceName = $autopilotDeviceNameTemplate | ConvertFrom-AutopilotDeviceNameTemplate
        $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('{0}')/setDeviceName" -f $deviceID
        $payload = @{
            "deviceName" = $newDeviceName
        }

        Write-Warning "Renaming $currentDeviceName to $newDeviceName"
        $null = Invoke-RestMethod -Uri $URI -Method POST -Body ($payload | ConvertTo-Json) -Headers $header -Verbose -ErrorAction Stop
    }
}
