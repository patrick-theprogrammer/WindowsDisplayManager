# A display source with corresponding display target to use if the source is enabled. Similar to a display "path" except with an optional target.
class Display {
    # Display source (eg graphics card output)
    [Source]$Source
    # Display target (eg monitor)- note target data is only available if the source is enabled
    [Target]$Target
    # See DisplayTypes.ps1xml for calculated properties

    Display (
        [uint32]$sourceId,
        [DisplayDevices+DisplayDevice]$sourceDevice) {
        $this.Source = [Source]::new($sourceId, $sourceDevice)
    }
    Display (
        [uint32]$sourceId,
        [DisplayDevices+DisplayDevice]$sourceDevice,
        [DisplayConfig+DisplayConfigPathTargetInfo]$pathTargetInfo) {
        $this.Source = [Source]::new($sourceId, $sourceDevice)
        $this.Target = [Target]::new($pathTargetInfo)
    }

    [bool]Equals($display) { return $this.Id -eq $display.Id }
    [string]ToJsonString() { return "`n" + ($this | ConvertTo-Json | Out-String).Trim() }
    [string]ToTableString() { return "`n" + ($this | Format-Table  | Out-String).Trim() }

    [bool]Disable() { return $this._SetEnablement($false, $null) }
    [bool]Enable() { return $this._SetEnablement($true, $null) }
    [bool]Enable($destinationTargetId) { return $this._SetEnablement($true, $destinationTargetId) }
    [bool]SetResolution($width, $height, $refreshRate) {
        return $this.Source._SetResolution($width, $height, $refreshRate)
    }
    [bool]SetResolution($width, $height) { return $this.SetResolution($width, $height, $null) }
    [bool]SetToRecommendedResolution() {
        $recommendedResolution = $this.Target._GetRecommendedResolution()
        if (-not $recommendedResolution) { return $false }
        return $this.SetResolution($recommendedResolution.Width, $recommendedResolution.Height)
    }
    [bool]EnableHdr() {
        if (-not $this.Target) { return $true }
        return $this.Target._SetHdrEnablement($true)
    }
    [bool]DisableHdr() {
        if (-not $this.Target) { return $true }
        return $this.Target._SetHdrEnablement($false)
    }

    [bool]_GetIsEnabled() {
        $configInfo = $this._GetDisplayConfigInfo($false)
        if ($null -eq $configInfo) { return $null }
        foreach ($path in $configInfo.Paths) {
            # Paths should always be keyed on source and target id, so we can safely return the first match based on those ids
            if (($path.sourceInfo.id -eq $this.Source.Id) -and ($path.targetInfo.id -eq $this.Target.Id)) {
                # Since we didn't fetch inactive paths from display config, all returned paths should be active. Check it anyways to be safe.
                return $path.flags.HasFlag([DisplayConfig+DisplayConfigPathInfoFlags]::PathActive)                
            }
        }
        # If the display isn't enabled, there won't be an active path for it
        return $false
    }

    hidden [bool]_SetEnablement($enablement, $destinationTargetId) {
        $actualDestinationTargetId = $null
        if ($enablement) {
            if ($destinationTargetId) { $actualDestinationTargetId = $destinationTargetId }
            elseif ($this.Target) { $actualDestinationTargetId = $this.Target.Id }              
            else { 
                Write-PSFMessage -Level Debug -Message "Display $($this.Description) cannot be enabled since it does not have a target stored from when it was created and one wasn't supplied"
                return $true
            }
        }
        elseif ($this.Primary) {
            Write-PSFMessage -Level Debug -Message "Display $($this.Description) cannot be disabled since it is the primary display"
            return $true
        }
        # To enable a display, we need paths that aren't active in order to activate one. To disable one, it is ok to get only active paths.
        $configInfo = $this._GetDisplayConfigInfo($enablement)
        if ($null -eq $configInfo) { return $false }
        for ($pathIndex = 0; $pathIndex -lt $configInfo.Paths.Length; $pathIndex++) {
            $path = $configInfo.Paths[$pathIndex]
            if ($path.sourceInfo.id -ne $this.Source.Id) { continue }
            if ($enablement -and $path.targetInfo.id -ne $actualDestinationTargetId) { continue }
            if ($enablement -and -not $path.targetInfo.targetAvailable) { continue }
            if ($enablement -eq $path.flags.HasFlag([DisplayConfig+DisplayConfigPathInfoFlags]::PathActive)) {
                Write-PSFMessage -Level Debug -Message "Path for Display $($this.Description) already has enablement state of $enablement, nothing to change"
                return $true
            }
            # Update the path active flag, validate and set enablement.
            if ($enablement) { $path.flags = $path.flags -bor [DisplayConfig+DisplayConfigPathInfoFlags]::PathActive }
            else { $path.flags = $path.flags -band (-bnot [DisplayConfig+DisplayConfigPathInfoFlags]::PathActive) }
            $configInfo.Paths[$pathIndex] = $path
            $validateSetDisplayConfigFlags = [DisplayConfig+SetDisplayConfigFlags]::Validate -bor [DisplayConfig+SetDisplayConfigFlags]::UseSuppliedDisplayConfig
            $validateSetDisplayConfigResult = [DisplayConfig]::SetDisplayConfig($configInfo.PathsCount, $configInfo.Paths, $configInfo.ModesCount, $configInfo.Modes, $validateSetDisplayConfigFlags)
            if ($validateSetDisplayConfigResult -ne [Win32Error]::ERROR_SUCCESS) {
                Write-PSFMessage -Level Critical -Message "Error validating the setting of display $($this.Description) enablement state to $enablement (error code $([Win32Error]$validateSetDisplayConfigResult))"
                return $false
            }
            $setDisplayConfigFlags = [DisplayConfig+SetDisplayConfigFlags]::Apply -bor [DisplayConfig+SetDisplayConfigFlags]::UseSuppliedDisplayConfig `
                -bor [DisplayConfig+SetDisplayConfigFlags]::AllowChanges -bor [DisplayConfig+SetDisplayConfigFlags]::SaveToDatabase
            $setDisplayConfigResult = [DisplayConfig]::SetDisplayConfig($configInfo.PathsCount, $configInfo.Paths, $configInfo.ModesCount, $configInfo.Modes, $setDisplayConfigFlags)
            if ($setDisplayConfigResult -ne [Win32Error]::ERROR_SUCCESS) {
                Write-PSFMessage -Level Critical -Message "Error setting display $($this.Description) enablement state to $enablement (error code $([Win32Error]$setDisplayConfigResult))"
                return $false
            }
            Write-PSFMessage -Level Verbose -Message "Display $($this.Description) enablement state set to $enablement successfully"
            return $true
        }
        Write-PSFMessage -Level Debug -Message "No display configuration path found for display $($this.Description) when setting enablement to $($enablement): this likely indicates $(if ($enablement) 
        { "the destination target id $actualDestinationTargetId doesn't exist- maybe refresh monitor settings" } 
        else { "the display is already disabled" })" 
        return $true
    }

    hidden [PSCustomObject]_GetDisplayConfigInfo([bool]$includeInactivePaths) {
        $pathsCount = 0;
        $modesCount = 0;
        $queryDisplayConfigFlags = if ($includeInactivePaths) { [DisplayConfig+QueryDisplayConfigFlags]::AllPaths } else { [DisplayConfig+QueryDisplayConfigFlags]::OnlyActivePaths }
        $displayConfigBufferSizesResult = [DisplayConfig]::GetDisplayConfigBufferSizes($queryDisplayConfigFlags, [ref]$pathsCount, [ref]$modesCount);
        if ($displayConfigBufferSizesResult -ne [Win32Error]::ERROR_SUCCESS) {
            Write-PSFMessage -Level Critical -Message "Failed to get display configuration buffer sizes for display $($this.Description) (error code $([Win32Error]$displayConfigBufferSizesResult))"
            return $null
        }
        $paths = @()
        $modes = @()
        $displayConfigResult = [DisplayConfig]::QueryDisplayConfig($queryDisplayConfigFlags, [ref]$pathsCount, [ref]$paths, [ref]$modesCount, [ref]$modes);
        if ($displayConfigResult -ne [Win32Error]::ERROR_SUCCESS) {
            Write-PSFMessage -Level Critical -Message "Failed to get display configuration path for display $($this.Description) (error code $([Win32Error]$displayConfigResult))"
            return $null
        }
        return @{
            PathsCount = $pathsCount
            Paths      = $paths
            ModesCount = $modesCount
            Modes      = $modes
        }
    }
}

# A single potential means of graphics output
class Source {
    # Unique source identifier, typically an index (eg 0)
    [uint32]$Id
    # Source name (eg "\\.\DISPLAY1")
    [string]$Name
    # Source description, usually graphics card name (eg "Intel(R) HD Graphics Family")
    [string]$Description

    Source (
        [uint32]$sourceId,
        [DisplayDevices+DisplayDevice]$sourceDevice) {
        $this.Id = $sourceId
        $this.Name = $sourceDevice.DeviceName
        $this.Description = $sourceDevice.DeviceString
    }

    # Per MSDN: "whether a monitor is presented as being "on" by the respective GDI view"
    hidden [bool]_GetIsActive() {
        $displayDevice = $this._GetDisplayDevice()
        if ($null -eq $displayDevice) { return $false }
        return $displayDevice.StateFlags.HasFlag([DisplayDevices+DisplayDeviceStateFlags]::DeviceActive)
    }

    # Source is primary (only one display can have this)
    hidden [bool]_GetIsPrimary() {
        $displayDevice = $this._GetDisplayDevice()
        if ($null -eq $displayDevice) { return $false }
        return $displayDevice.StateFlags.HasFlag([DisplayDevices+DisplayDeviceStateFlags]::PrimaryDevice)
    }

    # Configured output resolution and refresh rate- note return value is actually Resolution but PsCustomObject makes it nullable
    hidden [PsCustomObject]_GetResolution() {
        if (-not $this._GetIsActive()) { return $null }
        $deviceMode = $this._GetDisplaySettingsDeviceMode()
        if ($null -eq $deviceMode) { return $null }
        return [Resolution]::new($deviceMode.dmPelsWidth, $deviceMode.dmPelsHeight, $deviceMode.dmDisplayFrequency)
    }

    # (x, y) Position in a multi monitor setup
    hidden [PsCustomObject]_GetPosition() {
        if (-not $this._GetIsActive()) { return $null }
        $deviceMode = $this._GetDisplaySettingsDeviceMode()
        if ($null -eq $deviceMode) { return $null }
        return [Position]::new($deviceMode.dmPositionX, $deviceMode.dmPositionY)
    }

    hidden [bool]_SetResolution($width, $height, $refreshRate) {
        if (-not $this._GetIsActive()) { 
            Write-PSFMessage -Level Debug -Message "Cannot set resolution of disabled display source $($this.Name)"
            return $true
        }
        $deviceMode = $this._GetDisplaySettingsDeviceMode()
        if ($null -eq $deviceMode) { return $false }
        $refreshRateTolerance = 3 # Tolerance for when to consider a refresh rate close enough to not need changing
        $refreshRateWithinTolerance = -not $refreshRate -or ([Math]::Abs($deviceMode.dmDisplayFrequency - $refreshRate) -le $refreshRateTolerance)
        if ($deviceMode.dmPelsWidth -eq $width -and $deviceMode.dmPelsHeight -eq $height -and $refreshRateWithinTolerance) {
            Write-PSFMessage -Level Debug -Message "Current resolution for source $($this.Name) of $($deviceMode.dmPelsWidth)x$($deviceMode.dmPelsHeight)x$($deviceMode.dmDisplayFrequency) is equivalent to requested resolution- nothing to change"
            return $true
        }
        $requestedResolutionStr = "$($width)x$($height)$(if($refreshRate){"@$($refreshRate)fps"})"
        $deviceMode.dmPelsWidth = $width
        $deviceMode.dmPelsHeight = $height
        if ($refreshRate) { $deviceMode.dmDisplayFrequency = $refreshRate }
        $validateChangeDisplaySettingsResult = [DisplaySettings]::ChangeDisplaySettingsEx($this.Name, [ref]$deviceMode, [DisplaySettings+ChangeDisplaySettingsFlags]::Test)
        if ($validateChangeDisplaySettingsResult -ne [DisplaySettings+ChangeDisplaySettingsResult]::DISP_CHANGE_SUCCESSFUL) {
            Write-PSFMessage -Level Warning -Message "Failed to validate source $($this.Name) display settings could be changed to $requestedResolutionStr (error code $([DisplaySettings+ChangeDisplaySettingsResult]$validateChangeDisplaySettingsResult))"
            return $false
        }
        $changeDisplaySettingsResult = [DisplaySettings]::ChangeDisplaySettingsEx($this.Name, [ref]$deviceMode, [DisplaySettings+ChangeDisplaySettingsFlags]::UpdateRegistry)
        if ($changeDisplaySettingsResult -ne [DisplaySettings+ChangeDisplaySettingsResult]::DISP_CHANGE_SUCCESSFUL) {
            Write-PSFMessage -Level Critical -Message "Failed to change resolution to $requestedResolutionStr for source $($this.Name) (error code $([DisplaySettings+ChangeDisplaySettingsResult]$changeDisplaySettingsResult))"
            return $false
        }
        Write-PSFMessage -Level Verbose -Message "Source $($this.Name) resolution successfully set to $requestedResolutionStr"
        return $true
    }

    # Return value is in structure DisplaySettings+DevMode, use PSCustomObject to make it nullable
    hidden [PSCustomObject]_GetDisplaySettingsDeviceMode() {
        $deviceMode = New-Object DisplaySettings+DevMode
        $deviceMode.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($deviceMode)
        $enumDisplaySettingsMode = [DisplaySettings+EnumDisplaySettingsMode]::CurrentSettings
        $enumDisplaySettingsFlags = [DisplaySettings+EnumDisplaySettingsFlags]::RotatedMode
        $enumDisplaySettingsResult = [DisplaySettings]::EnumDisplaySettingsEx($this.Name, $enumDisplaySettingsMode, [ref]$deviceMode, $enumDisplaySettingsFlags)
        if (-not $enumDisplaySettingsResult) {
            Write-PSFMessage -Level Critical -Message "Failed to get device mode for source $($this.Name)"
            return $null
        }
        return $deviceMode
    }

    # Return value is in structure DisplayDevices+DisplayDevice, use PSCustomObject to make it nullable
    hidden [PSCustomObject]_GetDisplayDevice() {
        $displayDevice = New-Object DisplayDevices+DisplayDevice
        $displayDevice.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($displayDevice)
        $enumDisplayDevicesResult = [DisplayDevices]::EnumDisplayDevices([NullString]::Value, $this.Id, [ref]$displayDevice, [DisplayDevices+EnumDisplayDevicesFlags]::None)
        if (-not $enumDisplayDevicesResult) {
            Write-PSFMessage -Level Critical -Message "Failed to get display device for source $($this.Name) (error code $([Win32Error]$enumDisplayDevicesResult))"
            return $null
        }
        return $displayDevice
    }
}

# The connection and/or display to which the source is outputting
class Target {
    # Unique target identifiers
    [uint32]$Id
    # TODO the target and source adapter ids seem to always be the same, even though we only need the target one. Should this just live at the Display level?
    [DisplayConfig+LUID]$AdapterId
    # Friendly target name similar to what a user would see in Windows settings:
    # From EDID if available, else generic based on output technology, else "Unknown"
    [string]$FriendlyName
    # The type of output technology being used eg HDMI or DisplayPort
    [string]$ConnectionType

    Target ([DisplayConfig+DisplayConfigPathTargetInfo]$pathTargetInfo) {
        # TODO require the below to be valid
        $this.Id = $pathTargetInfo.id
        $this.AdapterId = $pathTargetInfo.adapterId
        
        # Side load friendly name from DisplayConfigGetDeviceInfo at object build time- it's only informational.
        $targetName = New-Object DisplayConfig+DisplayConfigTargetDeviceName
        $targetNameHeader = New-Object DisplayConfig+DisplayConfigDeviceInfoHeader
        $targetNameHeader.id = $this.Id
        $targetNameHeader.adapterId = $this.AdapterId
        $targetNameHeader.size = [uint32]([System.Runtime.InteropServices.Marshal]::SizeOf($targetName))
        $targetNameHeader.type = [DisplayConfig+DisplayConfigDeviceInfoType]::DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME
        $targetName.header = $targetNameHeader
        $targetNameResult = [DisplayConfig]::DisplayConfigGetDeviceInfo([ref]$targetName)
        $this.FriendlyName = "Unknown"
        $this.ConnectionType = [string]$pathTargetInfo.outputTechnology
        if ($targetNameResult -eq [Win32Error]::ERROR_SUCCESS) {
            if ($targetName.flags.value.HasFlag([DisplayConfig+DisplayConfigTargetDeviceNameFlagValue]::FRIENDLY_NAME_FROM_EDID)) {
                $this.FriendlyName = $targetName.monitorFriendlyDeviceName
            }
        }
        else { 
            Write-PSFMessage -Level Warning -Message "Error fetching friendly name for target id $($this.Id) (error code $([Win32Error]$targetNameResult))" 
        }
        if ($this.FriendlyName -eq "Unknown") {
            if (-not ([string]::IsNullOrWhitespace($pathTargetInfo.outputTechnology))) {
                $this.FriendlyName = [string]$pathTargetInfo.outputTechnology + " Display"
            }
            else {
                Write-PSFMessage -Level Debug -Message "Unable to find friendly name from fetched target information for target id $($this.Id)"
            }
        }
    }

    # HDR support and enablement info
    hidden [HdrInfo]_GetHdrInfo() {
        $advancedColorInfo = New-Object DisplayConfig+DisplayConfigGetAdvancedColorInfo
        $advancedColorInfoHeader = New-Object DisplayConfig+DisplayConfigDeviceInfoHeader
        $advancedColorInfoHeader.id = $this.Id
        $advancedColorInfoHeader.adapterId = $this.AdapterId
        $advancedColorInfoHeader.size = [uint32]([System.Runtime.InteropServices.Marshal]::SizeOf($advancedColorInfo));
        $advancedColorInfoHeader.type = [DisplayConfig+DisplayConfigDeviceInfoType]::DISPLAYCONFIG_DEVICE_INFO_GET_ADVANCED_COLOR_INFO;
        $advancedColorInfo.header = $advancedColorInfoHeader
        $advancedColorInfoResult = [DisplayConfig]::DisplayConfigGetDeviceInfo([ref]$advancedColorInfo);
        if ($advancedColorInfoResult -ne [Win32Error]::ERROR_SUCCESS) {
            Write-PSFMessage -Level Critical -Message "Failed to get HDR info for target $($this.FriendlyName) (error code $([Win32Error]$advancedColorInfoResult))"
            return $null
        }
        $hdrSupported = $advancedColorInfo.values.HasFlag([DisplayConfig+DisplayConfigGetAdvancedColorInfoValues]::AdvancedColorSupported)
        $hdrEnabled = $advancedColorInfo.values.HasFlag([DisplayConfig+DisplayConfigGetAdvancedColorInfoValues]::AdvancedColorEnabled)
        return [HdrInfo]::new($hdrSupported, $hdrEnabled, $advancedColorInfo.bitsPerColorChannel)
    }

    # Recommended target resolution per EDID (note recommended refresh rate is not available)
    hidden [Resolution]_GetRecommendedResolution() {
        $targetPreferredMode = New-Object DisplayConfig+DisplayConfigTargetPreferredMode
        $targetPreferredModeHeader = New-Object DisplayConfig+DisplayConfigDeviceInfoHeader
        $targetPreferredModeHeader.id = $this.Id
        $targetPreferredModeHeader.adapterId = $this.AdapterId
        $targetPreferredModeHeader.size = [uint32]([System.Runtime.InteropServices.Marshal]::SizeOf($targetPreferredMode));
        $targetPreferredModeHeader.type = [DisplayConfig+DisplayConfigDeviceInfoType]::DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_PREFERRED_MODE;
        $targetPreferredMode.header = $targetPreferredModeHeader
        $targetPreferredModeResult = [DisplayConfig]::DisplayConfigGetDeviceInfo([ref]$targetPreferredMode);
        if ($targetPreferredModeResult -ne [Win32Error]::ERROR_SUCCESS) {
            Write-PSFMessage -Level Critical -Message "Failed to get recommended resolution for target $($this.FriendlyName) (error code $([Win32Error]$targetPreferredModeResult))"
            return $null
        }
        return [Resolution]::new($targetPreferredMode.width, $targetPreferredMode.height)
    }

    hidden [bool]_SetHdrEnablement($enablement) {
        $currentHdrInfo = $this._GetHdrInfo()
        if ($null -eq $currentHdrInfo) { return $false }
        if (-not $currentHdrInfo.HdrSupported) {
            Write-PSFMessage -Level Debug -Message "HDR is not supported for target $($this.FriendlyName), unable to change HDR enablement to $enablement"
            return $true
        }
        if ($currentHdrInfo.HdrEnabled -eq $enablement) {
            Write-PSFMessage -Level Debug -Message "HDR enablement state is already $enablement for target $($this.FriendlyName), nothing to change"
            return $true
        }
        $setAdvancedColorInfo = New-Object DisplayConfig+DisplayConfigSetAdvancedColorInfo
        $setAdvancedColorInfoHeader = New-Object DisplayConfig+DisplayConfigDeviceInfoHeader
        $setAdvancedColorInfoHeader.id = $this.Id
        $setAdvancedColorInfoHeader.adapterId = $this.AdapterId
        $setAdvancedColorInfoHeader.size = [uint32]([System.Runtime.InteropServices.Marshal]::SizeOf($setAdvancedColorInfo));
        $setAdvancedColorInfoHeader.type = [DisplayConfig+DisplayConfigDeviceInfoType]::DISPLAYCONFIG_DEVICE_INFO_SET_ADVANCED_COLOR_STATE;
        if ($enablement) {
            $setAdvancedColorInfo.values = $setAdvancedColorInfo.values -bor [DisplayConfig+DisplayConfigSetAdvancedColorInfoValues]::EnableAdvancedColor
        }
        else {
            $setAdvancedColorInfo.values = $setAdvancedColorInfo.values -band (-bnot [DisplayConfig+DisplayConfigSetAdvancedColorInfoValues]::EnableAdvancedColor)
        }
        $setAdvancedColorInfo.header = $setAdvancedColorInfoHeader
        $setAdvancedColorInfoResult = [DisplayConfig]::DisplayConfigSetDeviceInfo([ref]$setAdvancedColorInfo);
        if ($setAdvancedColorInfoResult -ne [Win32Error]::ERROR_SUCCESS) {
            Write-PSFMessage -Level Critical -Message "Failed to set HDR enablement target $($this.FriendlyName) (error code $([Win32Error]$setAdvancedColorInfoResult))"
            return $false
        }
        Write-PSFMessage -Level Verbose -Message "HDR enablement for target $($this.FriendlyName) set successfully to $enablement"
        return $true
    }

    hidden [DisplayConfig+DisplayConfigDeviceInfoHeader]_GetBaseDisplayConfigHeader() {
        $displayConfigHeader = New-Object DisplayConfig+DisplayConfigDeviceInfoHeader
        $displayConfigHeader.id = $this.Id
        $displayConfigHeader.adapterId = $this.AdapterId
        return $displayConfigHeader
    }
}

class Resolution {
    [uint16]$Width # in pixels
    [uint16]$Height # in pixels
    [uint16]$RefreshRate # in fps

    Resolution() {}
    Resolution($width, $height) {
        $this.Width = $width
        $this.Height = $height
    }
    Resolution($width, $height, $refreshRate) {
        $this.Width = $width
        $this.Height = $height
        $this.RefreshRate = $refreshRate
    }
}

class HdrInfo {
    # Whether the display supports HDR
    [bool]$HdrSupported
    # Whether HDR is enabled per settings for the display
    [bool]$HdrEnabled
    # Bits per color channel aka bit depth
    [int]$BitDepth

    HdrInfo() {}
    HdrInfo($hdrSupported, $hdrEnabled, $bitDepth) {
        $this.HdrSupported = $hdrSupported
        $this.HdrEnabled = $hdrEnabled
        $this.BitDepth = $bitDepth
    }
}

# Simple coordinate holder for eg multi monitor settings
class Position {
    [int16]$X
    [int16]$Y

    Position() {}
    Position($xCoordinate, $yCoordinate) {
        $this.X = $xCoordinate
        $this.Y = $yCoordinate
    }
}