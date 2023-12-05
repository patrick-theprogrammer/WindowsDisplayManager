$maxNbrDisplaysSupported = 100

function GetAllPotentialDisplays() {
    # Loop through all display devices by index starting at 0 until no display is returned
    $displays = @()
    for ($i = 0; $i -lt $maxNbrDisplaysSupported; $i++) {
        $display = _GetDisplay($i)
        # If there is no display at index i, we can assume there are only i-1 displays in the system
        if ($null -eq $display) { return $displays }
        $displays += $display
    }
    return $displays
}

function GetEnabledDisplays() {
    $enabledDisplays = @()
    foreach ($display in GetAllPotentialDisplays) {
        if ($display.Enabled) { $enabledDisplays += $display }
    }
    if ($enabledDisplays.Length -eq 0) { Write-PSFMessage -Level Warning -Message "No enabled displays found" }
    return $enabledDisplays
}

function GetPrimaryDisplay() {
    for ($i = 0; $i -lt $maxNbrDisplaysSupported; $i++) {
        $display = _GetDisplay($i)
        if ($display.Primary) { return $display }
    }
    Write-PSFMessage -Level Warning -Message "No primary display found"
    return $null
}

function GetDisplayByMonitorName($monitorName) {
    # Gets the first enabled display if any with the target friendly name of monitorName
    for ($i = 0; $i -lt $maxNbrDisplaysSupported; $i++) {
        $display = _GetDisplay($i)
        if ($display.Target.FriendlyName -eq $monitorName) { return $display }
    }
    Write-PSFMessage -Level Debug -Message "No display found for monitor $monitorName. Is the display enabled?"
    return $null
}

function _GetDisplay($index) {
    # We expect an error if the display source at that index does not exist- still try to fetch a couple times to be safe in case of any transient failures
    $maxAttempts = 2
    $attemptDelayMs = 100
    for ($i = 0; $i -lt $maxAttempts; $i++) {
        Start-Sleep -Milliseconds $attemptDelayMs

        $displayDevice = New-Object DisplayDevices+DisplayDevice
        $displayDevice.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($displayDevice)
        $enumDisplayDevicesResult = [DisplayDevices]::EnumDisplayDevices([NullString]::Value, $index, [ref]$displayDevice, [DisplayDevices+EnumDisplayDevicesFlags]::None)
        if (-not $enumDisplayDevicesResult) { continue }

        $pathsCount = 0;
        $modesCount = 0;
        $displayConfigBufferSizesResult = [DisplayConfig]::GetDisplayConfigBufferSizes([DisplayConfig+QueryDisplayConfigFlags]::OnlyActivePaths, [ref]$pathsCount, [ref]$modesCount);
        if ([Win32Error]$displayConfigBufferSizesResult -ne [Win32Error]::ERROR_SUCCESS) {
            Write-PSFMessage -Level Critical -Message "Failed to get display configuration buffer for source index $index (error code $([Win32Error]$displayConfigBufferSizesResult))"
            continue
        }
        $paths = @()
        $modes = @()
        $displayConfigResult = [DisplayConfig]::QueryDisplayConfig([DisplayConfig+QueryDisplayConfigFlags]::OnlyActivePaths, [ref]$pathsCount, [ref]$paths, [ref]$modesCount, [ref]$modes);
        if ([Win32Error]$displayConfigResult -ne [Win32Error]::ERROR_SUCCESS) {
            Write-PSFMessage -Level Critical -Message "Failed to get display configuration for source index $index (error code $([Win32Error]$displayConfigResult))"
            continue
        }

        foreach ($path in $paths) {
            if ($path.sourceInfo.id -eq $index) {
                return [Display]::new($path.sourceInfo.id, $displayDevice, $path.targetInfo)
            }
        }
        return [Display]::new($index, $displayDevice)
    }
    Write-PSFMessage -Level Debug -Message "Consistently failed to get display index $index- this indicates there are less than $($index+1) display sources"
    return $null
}

function GetRefreshedDisplay($display) {
    # Get any potential display currently at the source id of the input display
    return _GetDisplay($display.Source.Id)
}

# TODO find out why the positions aren't getting applied properly (one is just getting placed next to the other, despite us supplying the correct offset values)
function SetPrimaryDisplay($display) {
    $enabledDisplays = GetEnabledDisplays
    $displayToUpdate = $null
    foreach ($enabledDisplay in $enabledDisplays) {
        if (-not $enabledDisplay.Equals($display)) { continue }
        if ($enabledDisplay.Primary) {
            Write-PSFMessage -Level Debug -Message "Display $($enabledDisplay.Description) is already the primary display, nothing to change"
            return $true
        }
        $displayToUpdate = $enabledDisplay
    }
    if (-not $displayToUpdate) {
        Write-PSFMessage -Level Debug -Message "Unable to set Display $($display.Description) as primary- could not find currently enabled display at its source and target"
        return $true
    }

    $displayToUpdateDeviceMode = $displayToUpdate.Source._GetDisplaySettingsDeviceMode()
    if ($null -eq $displayToUpdateDeviceMode) { return $false }
    $positionOffset = [Position]::new($displayToUpdateDeviceMode.dmPositionX, $displayToUpdateDeviceMode.dmPositionY)

    $displayToUpdateDeviceMode.dmPositionX = 0
    $displayToUpdateDeviceMode.dmPositionY = 0
    $primaryChangeDisplaySettingsFlags = [DisplaySettings+ChangeDisplaySettingsFlags]::UpdateRegistry -bor [DisplaySettings+ChangeDisplaySettingsFlags]::SetPrimary -bor [DisplaySettings+ChangeDisplaySettingsFlags]::NoReset
    $primaryChangeDisplaySettingsResult = [DisplaySettings]::ChangeDisplaySettingsEx($displayToUpdate.Source.Name, [ref]$displayToUpdateDeviceMode, $primaryChangeDisplaySettingsFlags)
    if ($primaryChangeDisplaySettingsResult -ne [DisplaySettings+ChangeDisplaySettingsResult]::DISP_CHANGE_SUCCESSFUL) {
        Write-PSFMessage -Level Critical -Message "Failed to adjust position of display $($displayToUpdate.Description) (error code $([DisplaySettings+ChangeDisplaySettingsResult]$primaryChangeDisplaySettingsResult))"
        return $false
    }

    foreach ($enabledDisplay in $enabledDisplays) {
        if ($enabledDisplay.Equals($displayToUpdate)) { continue }
        if (-not $enabledDisplay.Source._GetIsActive()) { continue }
        $otherDisplayDeviceMode = $enabledDisplay.Source._GetDisplaySettingsDeviceMode()
        if ($null -eq $otherDisplayDeviceMode) { return $false }
        $otherDisplayDeviceMode.dmPositionX -= $positionOffset.X
        $otherDisplayDeviceMode.dmPositionY -= $positionOffset.Y
        Write-PSFMessage -Level Debug -Message "Display $($enabledDisplay.Description) will be moved to position $($otherDisplayDeviceMode.dmPositionX),$($otherDisplayDeviceMode.dmPositionY)"
        $otherChangeDisplaySettingsFlags = [DisplaySettings+ChangeDisplaySettingsFlags]::UpdateRegistry -bor [DisplaySettings+ChangeDisplaySettingsFlags]::NoReset
        $otherChangeDisplaySettingsResult = [DisplaySettings]::ChangeDisplaySettingsEx($enabledDisplay.Source.Name, [ref]$otherDisplayDeviceMode, $otherChangeDisplaySettingsFlags)
        if ($otherChangeDisplaySettingsResult -ne [DisplaySettings+ChangeDisplaySettingsResult]::DISP_CHANGE_SUCCESSFUL) {
            Write-PSFMessage -Level Critical -Message "Failed to adjust position of display $($enabledDisplay.Description) (error code $([DisplaySettings+ChangeDisplaySettingsResult]$otherChangeDisplaySettingsResult))"
            return $false
        }
    }

    $commitChangeDisplaySettingsResult = [DisplaySettings]::ChangeDisplaySettingsEx([NullString]::Value)
    if ($commitChangeDisplaySettingsResult -ne [DisplaySettings+ChangeDisplaySettingsResult]::DISP_CHANGE_SUCCESSFUL) {
        Write-PSFMessage -Level Critical -Message "Unable to set Display $($display.Description) as primary- failed to commit display settings (error code $([DisplaySettings+ChangeDisplaySettingsResult]$commitChangeDisplaySettingsResult))"
        return $false
    }
    Write-PSFMessage -Level Verbose -Message "Display $($displayToUpdate.Description) set successfully as primary display"
    return $true
}

function SaveDisplaysToFile($displays, $filePath) {
    try {
        ($displays | ConvertTo-Json | Out-String).Trim() | Set-Content -Path $filePath
        return $true
    }
    catch {
        Write-PSFMessage -Level Critical -Message "Error saving displays to file $filePath" -ErrorRecord $_
        return $false
    }
}

function LoadDisplayStatesFromFile($filePath) {
    return (Get-Content -Raw -Path $filePath | ConvertFrom-Json)
}

function UpdateDisplaysFromFile() {
    param(
        [string]$filePath,
        # Option of whether to disable any currently enabled displays which are not present in the specified display states
        [switch]$disableNotSpecifiedDisplays
    )

    $displayStates = LoadDisplayStatesFromFile -filePath $filePath
    if (-not $displayStates) { return $false }
    return UpdateDisplaysToStates -displayStates $displayStates -disableNotSpecifiedDisplays:$disableNotSpecifiedDisplays
}

function UpdateDisplaysToStates() {
    param(
        [PSCustomObject[]]$displayStates,
        # Option of whether to disable any currently enabled displays which are not present in the specified display states
        [switch]$disableNotSpecifiedDisplays,
        # Option of whether to double check that all updates occurred as expected after windows reports everything was successful
        [switch]$validate
    )

    if (-not $displayStates) {
        Write-PSFMessage -Level Verbose -Message "No display states specified- nothing to update"
        return $true
    }
    $allDisplays = GetAllPotentialDisplays
    if (-not $allDisplays) { return $false }
    Write-PSFMessage -Level Debug -Message "Updating displays to the following states:"
    $displayStates | ForEach-Object { Write-PSFMessage -Level Debug -Message $(($_ | ConvertTo-Json -Compress | Out-String).Trim()) }
    Write-PSFMessage -Level Debug -Message "Enabled displays before updating:"
    $allDisplays | ForEach-Object { if ($_.Enabled) { Write-PSFMessage -Level Debug -Message $($_.ToTableString()) } }
    $allUpdatesSuccessful = $true

    # First, enable any monitors and set primary as needed
    foreach ($displayState in @($displayStates)) {
        if ($displayState.Enabled -or $displayState.Primary) {
            $displayToUpdate = $null
            # Update the existing enabled display connected to the target if there is one, else the first available display source
            foreach ($display in $allDisplays) {
                if (($null -ne $displayState.Target.Id) -and ($display.Target.Id -eq $displayState.Target.Id)) {
                    $displayToUpdate = $display
                    break
                } elseif ((-not $displayToUpdate) -and ($display.Enabled -eq $false)) { 
                    $displayToUpdate = $display
                }
            }
            if (-not $displayToUpdate) {
                Write-PSFMessage -Level Warning -Message "No available display source found to enable for monitor $($displayState.Description)- are there open outputs on your host device?"
                continue
            }

            if (-not $displayToUpdate.Enable($displayState.Target.Id)) { $allUpdatesSuccessful = $false } 
            elseif ($displayToUpdate.Enabled) {
                # Refresh target info and set primary if required after effective enable
                $displayToUpdate = GetRefreshedDisplay -display $displayToUpdate
                if ($displayState.Primary) {
                    if (-not (SetPrimaryDisplay -display $displayToUpdate)) { $allUpdatesSuccessful = $false }
                }
            }
        }
    }

    # Enabling and setting primary for displays may effect source -> target mapping. Refresh the active displays so that everything is accurate
    $currentEnabledDisplays = GetEnabledDisplays

    # Then, set graphics settings or disable as needed
    foreach ($displayState in @($displayStates)) {
        $displayToUpdate = $null
        foreach ($enabledDisplay in $currentEnabledDisplays) {
            if (($null -ne $displayState.Target.Id) -and ($enabledDisplay.Target.Id -eq $displayState.Target.Id)) { 
                $displayToUpdate = $enabledDisplay
                break
            }
        }
        if (-not $displayToUpdate) {
            Write-PSFMessage -Level Debug -Message "No enabled display found to update for display state of $($displayState.Description)"
            continue
        }
        if ($displayState.Enabled -eq $false) { 
            if (-not $displayToUpdate.Disable()) { $allUpdatesSuccessful = $false }
            continue
        }
        if ($displayState.HdrInfo.HdrEnabled -is "boolean") {
            if ($displayState.HdrInfo.HdrEnabled) {
                if (-not $displayToUpdate.EnableHdr()) { $allUpdatesSuccessful = $false }
            } else {
                if (-not $displayToUpdate.DisableHdr()) { $allUpdatesSuccessful = $false }
            }
        }
        if (($null -ne $displayState.Resolution.Width) -and ($null -ne $displayState.Resolution.Height)) {
            # If we fail to set resolution with refresh rate, at least still try width x height
            if (-not ($displayToUpdate.SetResolution($displayState.Resolution.Width, $displayState.Resolution.Height, $displayState.Resolution.RefreshRate) `
                -or $displayToUpdate.SetResolution($displayState.Resolution.Width, $displayState.Resolution.Height))) {
                    $allUpdatesSuccessful = $false
            }
        }
    }

    # If requested, try to disable any currently enabled displays which aren't present in the file
    if ($disableNotSpecifiedDisplays) {
        foreach ($display in $currentEnabledDisplays) {
            if ((@($displayStates) | Where-Object { ($null -ne $_.Target.Id) -and ($_.Target.Id -eq $display.Target.Id) }).Length -eq 0) {
                if (-not $display.Disable()) { $allUpdatesSuccessful = $false }
            }
        }
    }

    Write-PSFMessage -Level Debug -Message "Enabled displays after updating:"
    # We may have disabled some displays in the last step- filter those out
    $currentEnabledDisplays | ForEach-Object {  if ($_.Enabled) { Write-PSFMessage -Level Debug -Message $($_.ToTableString()) } }

    # Validate no errors were encountered during update. If requested, wait a short time and double check everything was successful.
    if (-not $allUpdatesSuccessful) { return $false }
    if ($validate) {
        Start-Sleep -Milliseconds 500
        if (-not (CurrentDisplaysAreSameAsStates -validateAllEnabledDisplaysSpecified:$disableNotSpecifiedDisplays -displayStates $displayStates)) {
            Write-PSFMessage -Level Warning -Message "Unable to validate that all display settings were updated correctly"
            return $false
        }
    }
    return $true
}

function CurrentDisplaysAreSameAsFile() {
    param(
        [string]$filePath,
        # Option of whether to validate that all enabled displays are represented in the specified display states
        [switch]$validateAllEnabledDisplaysSpecified
    )

    $displayStates = LoadDisplayStatesFromFile -filePath $filePath
    if (-not $displayStates) { return $false }
    return CurrentDisplaysAreSameAsStates -validateAllEnabledDisplaysSpecified:$validateAllEnabledDisplaysSpecified -displayStates $displayStates
}

function CurrentDisplaysAreSameAsStates() {
    param(
        [PSCustomObject[]]$displayStates,
        # Option of whether to validate that all enabled displays are represented in the specified display states
        [switch]$validateAllEnabledDisplaysSpecified
    )

    $allDisplays = GetAllPotentialDisplays
    if (-not $allDisplays) { return $false }
    foreach ($display in $allDisplays) {
        $matchingDisplayState = $null
        foreach ($displayState in $displayStates) {
            if (($null -ne $displayState.Target.Id) -and ($display.Target.Id -eq $displayState.Target.Id)) {
                $matchingDisplayState = $displayState
                break
            } elseif (($null -eq $displayState.Target.Id) -and ($null -ne $displayState.Source.Id) -and ($display.Source.Id -eq $displayState.Source.Id)) { 
                $matchingDisplayState = $displayState
                break
            }
        }

        # If requested, fail if any currently enabled displays aren't in the file
        if ($validateAllEnabledDisplaysSpecified -and $display.Enabled -and -not $matchingDisplayState) { return $false }
        # Fail if any current display states don't match enablement of any matching record in the file
        if (($matchingDisplayState.Enabled -is "boolean") -and ($display.Enabled -ne $matchingDisplayState.Enabled)) { return $false }
        if (-not $matchingDisplayState) { continue }

        # Fail if resolution or hdr differ on any current display which is in the file
        if ($display.HdrInfo.HdrEnabled -ne $matchingDisplayState.HdrInfo.HdrEnabled) { return $false }
        $displayResolution = $display.Resolution
        $refreshRateTolerance = 3 # Tolerance for when to consider a refresh rate close enough to be considered equivalent
        if ($displayResolution.Width -ne $matchingDisplayState.Resolution.Width `
                -or $displayResolution.Height -ne $matchingDisplayState.Resolution.Height `
                -or ($displayResolution.RefreshRate -and [Math]::Abs($displayResolution.RefreshRate - $matchingDisplayState.Resolution.RefreshRate) -gt $refreshRateTolerance)) {
            return $false
        }
    }
    return $true
}
