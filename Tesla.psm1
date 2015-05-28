$Script:ScriptDir = Split-Path $MyInvocation.MyCommand.Path

. $Script:ScriptDir\Tesla.ps1
Export-ModuleMember -Function Connect-Tesla,Get-Tesla,Set-Tesla


<#
New-ModuleManifest -Path .\Tesla.psd1 `
                   -Guid 1d79bc55-90a2-4709-b8df-ddf559cc1e76 `
                   -Author 'Jon Newman' `
                   -Copyright 'Copyright (c) Jon Newman 2015 All rights reserved' `
                   -ModuleVersion 1.0 `
                   -Description 'Control your Tesla vehicle from PowerShell' `
                   -ScriptsToProcess .\Tesla.ps1 `
                   -FunctionsToExport Connect-Tesla,Get-Tesla,Set-Tesla `
                   -VariablesToExport @() `
                   -CmdletsToExport @()
#>
