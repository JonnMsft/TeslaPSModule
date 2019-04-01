# credit to HJespers for https://github.com/hjespers/teslams

#region Globals
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

[string]$TeslaPSModule_Uri = 'https://owner-api.teslamotors.com'
[string]$apiUri = "$TeslaPSModule_Uri/api/1"
[string]$TeslaPSModule_VehicleId = $null

[Hashtable]$headers = $null
[string]$activity = 'TeslaPSModule'

# emulate the android mobile app 
$version = '2.1.79'; 
$model = 'SM-G900V'; 
$codename = 'REL'; 
$release = '4.4.4'; 
$locale = 'en_US'; 
[string]$user_agent = "Model S $version ($model; Android $codename $release; $locale)"
#endregion Globals

#region Utility
function Status
{
    [CmdletBinding()]
    param(
        [string][parameter(Position=0,Mandatory=$true)]$Status
        )
    Write-Verbose -Message "$activity`: $Status"
    Write-Progress -Activity $activity -Status $Status
}

function CtoF([double][parameter(Mandatory=$true)]$celsius)
{
    return [Math]::Round($celsius * (9.0 / 5.0) + 32)
}
#endregion Utility

#region Invoke
function InvokeCarCommand
{
    [CmdletBinding()]
    param(
        [string][parameter(Mandatory=$true)]$command
        )
    GetConnection
    Status "Sending $command to vehicle..."
    $uri = "$apiUri/vehicles/$TeslaPSModule_VehicleId/command/$Command"
    Write-Verbose -Message $uri
    $resp = Invoke-RestMethod -Uri $uri `
                              -Method Post `
                              -Headers $headers `
                              -UserAgent $user_agent `
                              -ContentType 'application/json'
    Write-Debug -Message $resp
    Write-Debug -Message $resp.response
    if ($resp.response.result -ne "true")
    {
        throw "Error calling $command. Reason returned: ""$($resp.response.reason)"""
    }

    $script:m_delayTime = 5
}

function InvokeTeslaDataRequest
{
    [CmdletBinding()]
    param(
        [string][parameter(Mandatory=$true)]$Command
        )
    if (-not $activity)
    {
        $activity = "$($MyInvocation.InvocationName): $Command"
    }
    GetConnection
    $uri = "$apiUri/vehicles/$TeslaPSModule_VehicleId/data_request/$Command"
    Write-Verbose -Message "Sending command $uri"

    Status "Invoking $Command"
    $resp = Invoke-RestMethod -Uri $uri `
                              -Method Get `
                              -Headers $headers `
                              -UserAgent $user_agent `
                              -ContentType 'application/json'
    Write-Debug -Message $resp
    Write-Debug -Message $resp.response
    Write-Output -InputObject $resp.response

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
necessary to call this once for any computer+user.
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
        [string][parameter(ParameterSetName='VIN')]$VIN = '',
        [switch]$NoPersist
        )

    $activity = $MyInvocation.InvocationName
    $passwordBstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
    $plaintextpwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto($passwordBstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordBstr);

    $encr = '76492d1116743f0423413b16050a5345MgB8AFcATgBuAFcASABCAE8AWQA5AHUAbwArAFoASQBBAEwAOQBLAGwATgAwAHcAPQA9AHwAMQA5ADEAOAA0
AGEAMwBmAGEAMgAzAGUAMAAwAGQAMwAwAGEAMQBhADAAMwBhAGIAYwBlAGUAYwAzADAAMwAxADQANgBjADYAMgAxADkAMwBiADcAOAA3ADQAZQBkADQAMwA5ADkAZQA3A
GUAZQA4AGEAZQAwADIAYQAwADEAYgA5ADkAMwAyAGYAZAA4ADgAMQAxADMAYQA0ADEAOAA3ADAAZABjADIAOQA3AGUAMwA5ADUAMwA4ADIANAA0ADIANwAwAGEAYgBhAG
YAMgA2ADIAZQBjADUANgA1AGYAMAAwADMANwBmADgAOQAwAGEAMABhADAANABlAGYAOAA2ADIAZgA1ADEANwAyADIAZAAxAGEAYQBjADcAYQBiADUAYQBhADUAMgBlADM
AMQA4ADkAYgA4ADMAZgAzADYAZgBlAGUANwA4ADUANQA5ADIAMwBlADIAYwAyADQAMQAxAGYANwBhAGIAZQAwADgAZAA0AGUAZgAzAGYAYQAxADQAMQA5ADYAMQAwADcA
OABiADEAZAA5AGUANwAyADcAZgA0ADkAMABkAGUANwA0AGIANwBhADMAMAA2ADUAOQBiADQAOAA5AGYAOABiAGEAZABiADkAZgBhAGYAZQA0ADQAMQA1AGYANwBkAGQAN
gBlAGMAYQA5ADUANAA3ADEAMwAxADQAYwAxADQAMgA0AGMAOABjADAAZABiADgANwA4ADUAMABmADkANgBiADIAYQA5AGIAOQA3ADkAZQBmADQAMABiADIAYQAxAGEAYQ
BlADEAZgBhAGMANgAzAGEAMgA0ADkAYgA3AGMAMgBlAGIAZgA3ADAAZQA2AGUAOABiADgAZAAxADAAOAA4AGQAMgA4ADEAMwAxAGIAMwAyAGEAMwBjADMAOQAyAGIAMgA
wADYAYwBkADkANgBkADUAYQA3AGUAMgBiAGIANAAwADUANAA3ADQAZAA0AGEAYwA0ADEANwBlADYAOABkADgANgA0AGYANQBhADIAZAA5AGYAZQAzAGEANQBmADAAZQA3
ADQAZgA4AGEAZQA4AGUANwAzAGYAYwAyAGQAMgA0AGUAZgBkAGMAMQBhADkANAA1ADQAMwAyAGEAYQBkAGEAYgAwADAANgAxADAAMwBkADkAYwBjAGUAZAA2ADkAZQAzA
DcAMwBiAGMAMQA0AGIAMAA3ADcAMgBiAGIAOQA2AGQANQBlADcANwBiADYAYQA2ADMAMAA1ADQANQAyADcANQA3ADEAMABlADUANQAzAGMAZgBjADUAZAA1ADQAMQA5AG
IANQA0ADIAYgA4ADQANwAxADgAZQA1AGMAMwBmAGMAMQAzADIAMAAwADQAYgBkADAAMgA0AGQANgA0AGMAOABmAGYAMgAyAGMAOAAzADcANgA3AGIAMgBiAGYAYwBjADQ
ANQA5AGQAYgA2AGQAYgA='
    [byte[]]$k = ('236 231 222 136 19 9 157 113 158 51 236 240 116 17 176 100 91 179 20 162 238 103 10 192 113 251 135 59 95 82 109 114'.Split(' ')) -as [byte[]]
    $ps = ConvertTo-SecureString -String $encr -Key $k
    $b = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ps)
    $p = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($b)

    $loginBody = @{
        'grant_type' = 'password'
        'client_id' = ($p.Split(',')[0])
        'client_secret' = ($p.Split(',')[1])
        'email' = $Credential.UserName
        'password' = $plaintextpwd
        }
    Status "Login GET"
    $r = Invoke-RestMethod -Uri "$TeslaPSModule_Uri/oauth/token" `
                           -Method Post `
                           -Body $loginBody
    $r | Out-String | Write-Debug
    $access_token = $r.access_token
    $script:headers = @{
        'Authorization' = "Bearer $access_token"
        'Accept-Encoding' = 'gzip,deflate'
        }

    Status "Get vehicle list"
    $resp = Invoke-RestMethod -Uri "$apiUri/vehicles" `
                              -Method Get `
                              -UserAgent $user_agent `
                              -Headers $headers
    Write-Debug -Message $resp
    $vehicles = $resp.response
    $vehicles | Write-Debug
    Status "Received $($vehicles.Count) vehicles in response"
    if ($VIN)
    {
        for ($i = 0; $i -lt $vehicles.Count; $i++)
        {
            Status "Vehicle $i has VIN $($vehicle.VIN)"
            $vehicle = $vehicles[$i]
            if ($vehicle.VIN -eq $VIN)
            {
                Status "VIN match for vehicle $i"
                $VehicleIndex = $i;
                break
            }
        }
        if ($i -ge $vehicles.Count)
        {
            throw "$activity`: Vehicle with VIN $VIN not found"
        }
    }
    $vehicle = $vehicles[$VehicleIndex]
    $vehicleId = $vehicle.id
    Status "VehicleID is $vehicleId"

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
            Write-Debug -Message "$activity`: Exception $_"
            # Do nothing
        }

        # Check vehicle state periodically and continue when it's "online"
        do {
            Start-Sleep -Seconds 5
            Status "Checking whether vehicle woke up yet"
            $resp = Invoke-RestMethod -Uri "$apiUri/vehicles" `
                                         -Method Get `
                                         -UserAgent $user_agent `
                                         -Headers $headers
            $vehicle = $resp.response | Where-Object {$_.id -eq $vehicleId}
            Write-Verbose -Message "Vehicle state is $($vehicle.state)."
        }
        while ($vehicle.state -ne 'online')
    }

    Status "Caching connection"
    $script:TeslaPSModule_VehicleId = $vehicleId

    if (-not $NoPersist)
    {
        $fileName = Join-Path -Path $env:APPDATA -ChildPath 'TeslaPSModule_CachedConnection.xml'
        Status "Persisting cached connection to $fileName"
        $connection = New-Object -TypeName PSObject -Property @{
            Email = $Credential.UserName
            Password = $plaintextpwd
            VIN = $vehicle.VIN
            }
        $xmlContent = ConvertTo-Xml -InputObject $connection -As String
        Write-Verbose -Message "$activity`: Writing connection to file $fileName"
        $xmlContent = ConvertTo-SecureString -String $xmlContent -AsPlainText -Force | ConvertFrom-SecureString
        Set-Content -Path $fileName -Value $xmlContent -ErrorAction Stop
    }

    Write-Progress -Activity $activity -Status 'Completed' -Completed
}

function GetConnection
{
    [CmdletBinding()]
    param(
        )
    if ($headers -and $TeslaPSModule_VehicleId)
    {
        Write-Verbose -Message "Connection already cached"
        return
    }
    $path = Join-Path -Path $env:APPDATA -ChildPath 'TeslaPSModule_CachedConnection.xml'
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
            | ForEach-Object {[Runtime.InteropServices.Marshal]::PtrToStringAuto( `
                    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($_))}
        $xmlContent = [xml]$fileContentDecrypted

        $email = ($xmlContent.Objects.Object.Property | Where-Object {$_.Name -eq "Email"}).'#text'
        $password = ($xmlContent.Objects.Object.Property | Where-Object {$_.Name -eq "Password"}).'#text'
        $VIN = ($xmlContent.Objects.Object.Property | Where-Object {$_.Name -eq "VIN"}).'#text'
        $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
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
You must first call Connect-Tesla once to cache connection information
for this computer+user. Connection information will be encrypted and
cached in your user profile.
.PARAMETER Command
Specify the category of information you want to retrieve.
.LINK
Connect-Tesla
Set-Tesla
#>
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true,Position=0)]
        [ValidateSet('charge_state',
                     'climate_state',
                     'drive_state',
                     'gui_settings',
                     'vehicle_state',
                     'vehicle_config',
                     'vehicles'
                     )]
        [string]$Command
        )
    $activity = "$($MyInvocation.InvocationName): $Command"
    GetConnection
    if ($Command -eq 'vehicles')
    {
        Status "Reading vehicle list"
        $result = Invoke-RestMethod -Uri "$apiUri/vehicles" `
                                    -Method Get `
                                    -UserAgent $user_agent `
                                    -Headers $headers
        return $result.response
    }
    InvokeTeslaDataRequest -Command $Command
    Write-Progress -Activity $activity -Status 'Completed' -Completed
}

function Set-Tesla
{
<#
.SYNOPSIS
Change one setting of a Tesla vehicle
.DESCRIPTION
Change one setting of a Tesla vehicle.
You must first call Connect-Tesla once to cache connection information
for this computer+user. Connection information will be encrypted and
cached in your user profile.
.PARAMETER Command
Specify the command you want to issue.
.NOTES
Not yet implemented:
set_charge_limit <percent>
set_temps <driver_temp> <passenger_temp>
sun_roof_control (open | close | comfort | vent | move <percent>)
sun_roof_control move <percent>
streaming response from https://streaming.vn.teslamotors.com/stream/...
.LINK
Connect-Tesla
Get-Tesla
#>
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]
    param(
        [parameter(Mandatory=$true,Position=0)]
        [ValidateSet('auto_conditioning_start',
                     'auto_conditioning_stop',
                     'door_lock',
                     'door_unlock',
                     'charge_port_door_open',
                     'charge_max_range',
                     'charge_standard',
                     'charge_start',
                     'charge_stop',
                     'flash_lights',
                     'honk_horn',
                     'wake_up'
                     )]
        [string]$Command
        )
    $activity = "$($MyInvocation.InvocationName): $Command"
    if ($PSCmdlet.ShouldProcess($Command))
    {
        InvokeCarCommand $Command
    }
    Write-Progress -Activity $activity -Status 'Completed' -Completed
}

Export-ModuleMember Connect-Tesla,Get-Tesla,Set-Tesla
