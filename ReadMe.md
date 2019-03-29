# TeslaPSModule

Control your Tesla vehicle from PowerShell. Watch the demo at https://channel9.msdn.com/Events/PowerShell-Team/PowerShell-10-Year-Anniversary/PowerShell-For-My-Tesla!

## Tesla PowerShell Module

This module will enable you to call Tesla commands (like those from http://mytesla.com and your phone app) in a PowerShell script, and automate them in Scheduled Tasks etc. just like Windows services.

- Start your climate control automatically
- Log your physical location over time
- Use your imagination!

## Documentation

See the [TeslaPSModule wiki](https://github.com/JonnMsft/TeslaPSModule/wiki) for more info on the project.

## Installation

This module is available on PowerShell gallery! If you have Windows 10 or WMF 5.0 or other access to PowerShell Gallery, just run "Install-Module Tesla" or visit http://www.powershellgallery.com/packages/Tesla/.

Otherwise, you can install manually as follows:

1. Create folder `C:\Users\<username>\Documents\WindowsPowerShell\Modules\Tesla` 
2. Copy `Tesla.ps1` and `Tesla.psm1` into that directory. 
3. You will only have to call `Connect-Tesla` once (use your email and password as with http://mytesla.com), these will be encrypted and cached in your user profile. 
4. After that you can call `Get-Tesla` and `Set-Tesla` as much as you like.

This is a first release and not all functions are currently supported, although more can easily be added. 

Currently supported commands are:

- `Get-Tesla` commands:
	- `climate_state`
	- `charge_state`
	- `gui_settings`
	- `drive_state`
	- `vehicle_state`
	- `vehicle_config`
	- `vehicles`
- `Set-Tesla` commands: 
	- `mobile_enabled`
	- `auto_conditioning_start`
	- `auto_conditioning_stop`
	- `door_lock`
	- `door_unlock`
	- `sun_roof_control?state=close`
	- `sun_roof_control?state=comfort`
	- `sun_roof_control?state=vent`
	- `charge_stop`
	- `charge_start`

## Example Usage

PS> `Connect-Tesla`

 # Enter MyTesla.com web site credentials when prompted


PS> `Get-Tesla -Command drive_state`

`shift_state` :
 
`speed`       :

`latitude`    : 47.636793

`longitude`   : -122.134307

`heading`     : 265

`gps_as_of`   : 1432940624


PS> `Set-Tesla -Command auto_conditioning_start`


## Next Steps

The syntax for specific commands could be improved a bit, and this should eventually have proper installer / package manager package.

Fixes, suggestions, improvements etc. are all welcome via the GitHub repository.
[https://github.com/JonnMsft/TeslaPSModule](https://github.com/JonnMsft/TeslaPSModule)
