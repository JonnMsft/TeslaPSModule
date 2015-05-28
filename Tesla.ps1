#region Globals
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

[string]$TeslaPSModule_Uri = 'https://portal.vn.teslamotors.com'
# Alternate would be "http://timdorr.apiary.io"

[Microsoft.PowerShell.Commands.WebRequestSession]$TeslaPSModule_WebRequestSession = $null
[int]$TeslaPSModule_VehicleId = 0
#endregion Globals

#region Utility
function Status
{
    [CmdletBinding()]
    param(
        [string][parameter(Position=0,Mandatory=$true)]$Status
        )
    Write-Verbose "$activity`: $Status"
    Write-Progress -Activity $activity -Status $Status
}

function CtoF([double]$celsius)
{
    return [Math]::Round($celsius * (9.0 / 5.0) + 32)
}
#endregion Utility

#region Invoke
function InvokeCarCommand
{
    [CmdletBinding()]
    param(
        [string]$command
        )
    Status "Sending $command to vehicle..."

    $uri = "$TeslaPSModule_Uri/vehicles/$TeslaPSModule_VehicleId/command/$Command"
    Write-Debug $uri
    $resp = Invoke-RestMethod -Uri $uri -Method GET -WebSession $TeslaPSModule_WebRequestSession
    write-debug $resp
    if ($resp.result -ne "true")
    {
        throw "Error calling $command. Reason returned: ""$($resp.reason)"""
    }

    $script:m_delayTime = 5
}

function InvokeTeslaApi
{
    [CmdletBinding()]
    param(
        [string]$Command
        )
    if (-not $activity)
    {
        $activity = "$($MyInvocation.InvocationName): $Command"
    }
    GetConnection
    Write-Debug "TeslaPSModule_WebRequestSession = $TeslaPSModule_WebRequestSession"
    Write-Debug "TeslaPSModule_VehicleId = $TeslaPSModule_VehicleId"
    $uri = "$TeslaPSModule_Uri/vehicles/$TeslaPSModule_VehicleId/command/$Command"
    Write-Verbose "Sending command $uri to vehicle $TeslaPSModule_VehicleId"

    Status "Invoking $Command"
    $resp = Invoke-RestMethod -Uri $uri -Method GET -WebSession $TeslaPSModule_WebRequestSession
    Write-Debug $resp
    Write-Output $resp

    # CODEWORK still need to implement this $script:m_delayTime = 5
}
#endregion Invoke

#region Connect
function Connect-Tesla
{
<#
.SYNOPSIS
Connect to a vehicle
.DESCRIPTION
Connect to one Tesla vehicle. You must specify the credentials you use
to connect with the Tesla website, email address and password.
The credentials will be cached securely, so it should only be
necessary to call this once on any computer+user.
However you may need to invoke this again if you change
either your Tesla password or your Windows password.
.PARAMETER Credential
Specify the credentials you use to connect with the Tesla website,
email address and password.
.PARAMETER VehicleIndex
Specify this if you have more than one vehicle and want to connect
with a different vehicle than the first.
.PARAMETER VIN
Specify this if you have more than one vehicle and want to specify
the VIN of the specific vehicle.
.PARAMETER NoPersist
This will prevent your credentials from being cached.
They will only be effective for this PowerShell session.
.LINK
Get-Tesla
Set-Tesla
#>
    [CmdletBinding(DefaultParameterSetName='VehicleIndex')]
    param(
        [PSCredential][parameter(Mandatory=$true,Position=0)]$Credential,
        [int][parameter(ParameterSetName='VehicleIndex')]$VehicleIndex = 0,
        [string][parameter(ParameterSetName='VIN')]$VIN,
        [switch]$NoPersist
        )

    $activity = $MyInvocation.InvocationName
    $passwordBstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
    $plaintextpwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto($passwordBstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordBstr);
    $loginBody = @{
        "user_session[email]" = $Credential.UserName
        "user_session[password]" = $plaintextpwd
        }
    [Microsoft.PowerShell.Commands.WebRequestSession]$webRequestSession = $null
    Status "Login GET"
    $r = Invoke-RestMethod -Uri "$TeslaPSModule_Uri/login" -Method GET -SessionVariable webRequestSession
    # We ignore the return form.
    Status "Login POST"
    $loginBody | Out-String | Write-Debug
    $r = Invoke-RestMethod -Uri "$TeslaPSModule_Uri/login" -Method POST -WebSession $webRequestSession -Body $loginBody
    Status "Get vehicle list"
    $vehicles = @(Invoke-RestMethod -Uri "$TeslaPSModule_Uri/vehicles" -Method GET -WebSession $webRequestSession)
    if ($VIN)
    {
        for ($i = 0; $i -lt $vehicles.Count; $i++)
        {
            $vehicle = $vehicles[$i]
            if ($vehicles[$i].VIN -eq $VIN)
            {
                $VehicleIndex = $i;
                break
            }
            if ($i -ge $vehicles.Count)
            {
                throw "$activity`: Vehicle with VIN $VIN not found"
            }
        }
    }
    else
    {
        $vehicle = $vehicles[$VehicleIndex]
    }
    $vehicleId = $vehicle.id

    if ($vehicle.state -ne 'online') {
        if ($vehicle.state -ne 'asleep')
        {
            throw "$activity`: Current vehicle state is $($vehicle.state). Please try again later."
        }

        # The wake_up command will return error 408 (vehicle unavailable).
        try {
            Status "Waking vehicle"
            InvokeCarCommand wake_up
        }
        catch {
            # Do nothing
        }

        # Check vehicle state periodically and continue when it's "online"
        do {
            Start-Sleep -Seconds 5
            Status "Checking whether vehicle woke up yet"
            $vehicle = Invoke-RestMethod -Uri "$TeslaPSModule_Uri/vehicles" -Method GET -WebSession $TeslaPSModule_WebRequestSession
            $vehicle = $vehicle | ? id -eq $vehicleId
            Write-Verbose "Vehicle state is $($vehicle.state)."
        }
        while ($vehicle.state -ne 'online')
    }

    Status "Caching connection"
    $script:TeslaPSModule_WebRequestSession = $webRequestSession
    $script:TeslaPSModule_VehicleId = $VehicleId

    if (-not $NoPersist)
    {
        $fileName = Join-Path $env:APPDATA 'TeslaPSModule_CachedConnection.xml'
        Status "Persisting cached connection to $fileName"
        $connection = New-Object -TypeName PSObject -Property @{
            Email = $Credential.UserName
            Password = $plaintextpwd
            VIN = $vehicle.VIN
            }
        $xmlContent = ConvertTo-Xml $connection -As String
        Write-Debug "$activity`: Writing connection to file $fileName, contents:"
        Write-Debug $xmlContent
        $xmlContent = ConvertTo-SecureString $xmlContent -AsPlainText -Force | ConvertFrom-SecureString
        Set-Content -Path $fileName -Value $xmlContent -ErrorAction Stop
    }
}

function GetConnection
{
    [CmdletBinding()]
    param(
        )
    if ($TeslaPSModule_WebRequestSession)
    {
        Write-Debug "Connection already cached"
        return
    }
    $path = Join-Path $env:APPDATA 'TeslaPSModule_CachedConnection.xml'
    if (-not (Test-Path -Path $path -ErrorAction SilentlyContinue))
    {
        Status "You must first call Connect-Tesla"
        throw "You must first call Connect-Tesla"
    }

    Status "Reading cached connection from $path"
    try
    {
        $fileContent = Get-Content -Path $path -ErrorAction Stop
        $secureString = ConvertTo-SecureString -String $fileContent -ErrorAction SilentlyContinue
        $fileContentDecrypted = $secureString `
            | %{[Runtime.InteropServices.Marshal]::PtrToStringAuto( `
                    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($_))}
        $xmlContent = [xml]$fileContentDecrypted

        $email = ($xmlContent.Objects.Object.Property | ? Name -eq "Email").'#text'
        $password = ($xmlContent.Objects.Object.Property | ? Name -eq "Password").'#text'
        $VIN = ($xmlContent.Objects.Object.Property | ? Name -eq "VIN").'#text'
        $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
        $credential = New-Object -TypeName PSCredential -ArgumentList $email,$securePassword
    }
    catch
    {
        throw "Error reading cached connection; retry Connect-Tesla. Error is: $_"
    }
    Connect-Tesla -Credential $credential -VIN $VIN -NoPersist
}
#endregion Connect

function Get-Tesla
{
<#
.SYNOPSIS
Retrieve information about a Tesla vehicle
.DESCRIPTION
Retrieve information about a Tesla vehicle in a specific category.
You must first call Connect-Tesla for this computer+user.
.PARAMETER Command
Specify the category of information you want to retrieve.
.LINK
Connect-Tesla
Set-Tesla
#>
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true,Position=0)]
        [ValidateSet('climate_state',
                     'charge_state',
                     'gui_settings',
                     'drive_state',
                     'vehicle_state',
                     'vehicles'
                     )]
        [string]$Command
        )
    $activity = "$($MyInvocation.InvocationName): $Command"
    if ($Command -eq 'vehicles')
    {
        Status "Reading vehicle list"
        Invoke-RestMethod -Uri "$TeslaPSModule_Uri/vehicles" -Method GET -WebSession $TeslaPSModule_WebRequestSession
        return
    }
    InvokeTeslaApi -Command $Command
}

function Set-Tesla
{
<#
.SYNOPSIS
Change one setting of a Tesla vehicle
.DESCRIPTION
Change one setting of a Tesla vehicle.
You must first call Connect-Tesla for this computer+user.
.PARAMETER Command
Specify the setting you want to change.
.LINK
Connect-Tesla
Get-Tesla
#>
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true,Position=0)]
        [ValidateSet('mobile_enabled',
                     'auto_conditioning_start',
                     'auto_conditioning_stop',
                     'door_lock',
                     'door_unlock',
                     'sun_roof_control?state=close',
                     'sun_roof_control?state=comfort',
                     'sun_roof_control?state=vent',
                     'charge_stop',
                     'charge_start'
                     )]
        [string]$Command
        )
    $activity = "$($MyInvocation.InvocationName): $Command"
    InvokeCarCommand $Command
}
