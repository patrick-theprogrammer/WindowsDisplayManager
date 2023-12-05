# Simple script to import the public portion of all libraries in this directory
Set-Location $PSScriptRoot
Add-Type -Path .\Win32Interop\DisplayConfig.cs -IgnoreWarnings
Add-Type -Path .\Win32Interop\DisplayDevices.cs -IgnoreWarnings
Add-Type -Path .\Win32Interop\DisplaySettings.cs -IgnoreWarnings
Add-Type -Path .\Win32Interop\Win32Errors.cs -IgnoreWarnings
