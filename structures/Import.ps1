# Simple script to import all classes in this directory
using module .\Display\Display.psm1

Set-Location $PSScriptRoot
Update-TypeData -AppendPath .\Display\DisplayTypes.ps1xml
Update-FormatData -AppendPath .\Display\DisplayFormats.ps1xml
