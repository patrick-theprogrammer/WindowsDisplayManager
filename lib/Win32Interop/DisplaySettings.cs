using System;
using System.Runtime.InteropServices;

// Source: adapted from https://pinvoke.net/
public class DisplaySettings
{
    // See WinUser.h from Windows SDK for windows internal method definition
    // Use EnumDisplaySettingsEx instead to pass flags that allow fetching non standard (eg rotated) devices
    [DllImport("User32.dll", CharSet = CharSet.Unicode)]
    public static extern bool EnumDisplaySettings(
        [param: MarshalAs(UnmanagedType.LPWStr)]
        string deviceName,
        [param: MarshalAs(UnmanagedType.U4)] 
        EnumDisplaySettingsMode enumDisplaySettingsMode,
        [In, Out] ref DevMode deviceMode
    );

    [DllImport("User32.dll", CharSet = CharSet.Unicode)]
    public static extern bool EnumDisplaySettingsEx(
        [param: MarshalAs(UnmanagedType.LPWStr)]
        string deviceName,
        [param: MarshalAs(UnmanagedType.U4)] 
        EnumDisplaySettingsMode enumDisplaySettingsMode,
        [In, Out] ref DevMode deviceMode,
        [param: MarshalAs(UnmanagedType.U4)] 
        EnumDisplaySettingsFlags flags
    );

    // See wingdi.h from Windows SDK for windows internal method definition
    // See WinUser.h from Windows SDK for return val definition
    // ChangeDisplaySettings only changes the default device. For multi monitor setup, use ChangeDisplaySettingsEx.
    [DllImport("User32.dll", CharSet = CharSet.Unicode)]
    public static extern ChangeDisplaySettingsResult ChangeDisplaySettings(
        ref DevMode deviceMode,
        [param: MarshalAs(UnmanagedType.U4)] 
        ChangeDisplaySettingsFlags flags
    );

    [DllImport("User32.dll", CharSet = CharSet.Unicode)]
    private static extern ChangeDisplaySettingsResult ChangeDisplaySettingsEx(
        [param: MarshalAs(UnmanagedType.LPWStr)]
        string deviceName,
        ref DevMode deviceMode,
        // Reserved- should always be set to IntPtr.Zero (ie marshaled as null)
        IntPtr reserved,
        [param: MarshalAs(UnmanagedType.U4)] 
        ChangeDisplaySettingsFlags flags,
        // The actual type is a nullable out VideoParameters only required if flags has DatabaseCurrent
        // An IntPtr can still be marshaled allowing us to pass something recognized as a null pointer
        // TODO support somehow passing an actual DisplayConfigTopologyId if needed (marshalas IsAny?)
        IntPtr videoParameters
    );

    // Convenience wrapper to reduce unneccessary inputs and make it clear videoparameters aren't supported
    public static ChangeDisplaySettingsResult ChangeDisplaySettingsEx(
        string deviceName,
        ref DevMode deviceMode,
        [param: MarshalAs(UnmanagedType.U4)] 
        ChangeDisplaySettingsFlags flags) {
        return ChangeDisplaySettingsEx(deviceName, ref deviceMode, IntPtr.Zero, flags, IntPtr.Zero);
    }

    // Special case version of ChangeDisplaySettingsEx that takes null device name 
    // Used for committing a set of device registry changes queued up via NoReset flag
    [DllImport("user32.dll")]
    public static extern ChangeDisplaySettingsResult ChangeDisplaySettingsEx(
        [param: MarshalAs(UnmanagedType.LPWStr)]
        string deviceName,
        IntPtr deviceMode,
        IntPtr reserved,
        [param: MarshalAs(UnmanagedType.U4)] 
        ChangeDisplaySettingsFlags flags,
        IntPtr videoParameters);

    public static ChangeDisplaySettingsResult ChangeDisplaySettingsEx(string deviceName) {
        return ChangeDisplaySettingsEx(deviceName, IntPtr.Zero, IntPtr.Zero, ChangeDisplaySettingsFlags.Dynamic, IntPtr.Zero);
    }


    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct DevMode
    {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmDeviceName;
        [MarshalAs(UnmanagedType.U2)]
        public ushort dmSpecVersion;
        [MarshalAs(UnmanagedType.U2)]
        public ushort dmDriverVersion;
        [MarshalAs(UnmanagedType.U2)]
        public ushort dmSize;
        [MarshalAs(UnmanagedType.U2)]
        public ushort dmDriverExtra;
        [MarshalAs(UnmanagedType.U4)]
        public DeviceModeFields dmFields;
        [MarshalAs(UnmanagedType.I4)]
        public int dmPositionX;
        [MarshalAs(UnmanagedType.I4)]
        public int dmPositionY;
        [MarshalAs(UnmanagedType.U4)]
        public uint dmDisplayOrientation;
        [MarshalAs(UnmanagedType.U4)]
        public uint dmDisplayFixedOutput;
        [MarshalAs(UnmanagedType.I2)]
        public short dmColor;
        [MarshalAs(UnmanagedType.I2)]
        public short dmDuplex;
        [MarshalAs(UnmanagedType.I2)]
        public short dmYResolution;
        [MarshalAs(UnmanagedType.I2)]
        public short dmTTOption;
        [MarshalAs(UnmanagedType.I2)]
        public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmFormName;
        [MarshalAs(UnmanagedType.I2)]
        public short dmLogPixels;
        [MarshalAs(UnmanagedType.U2)]
        public ushort dmBitsPerPel;
        [MarshalAs(UnmanagedType.U4)]
        public uint dmPelsWidth;
        [MarshalAs(UnmanagedType.U4)]
        public uint dmPelsHeight;
        [MarshalAs(UnmanagedType.U4)]
        public uint dmDisplayFlags;
        [MarshalAs(UnmanagedType.U4)]
        public uint dmDisplayFrequency;
        [MarshalAs(UnmanagedType.U4)]
        public uint dmICMMethod;
        [MarshalAs(UnmanagedType.U4)]
        public uint dmICMIntent;
        [MarshalAs(UnmanagedType.U4)]
        public uint dmMediaType;
        [MarshalAs(UnmanagedType.U4)]
        public uint dmDitherType;
        [MarshalAs(UnmanagedType.U4)]
        public uint dmReserved1;
        [MarshalAs(UnmanagedType.U4)]
        public uint dmReserved2;
        [MarshalAs(UnmanagedType.U4)]
        public uint dmPanningWidth;
        [MarshalAs(UnmanagedType.U4)]
        public uint dmPanningHeight;
    }

    [Flags]
    public enum DeviceModeFields : uint
    {
        Position = 0x00000020,
        BitsPerPel = 0x00040000,
        PelsWidth = 0x00080000,
        PelsHeight = 0x00100000,
        DisplayFlags = 0x00200000,
        DisplayFrequency = 0x00400000
    }

    public enum EnumDisplaySettingsMode : int
    {
        /// <summary>Returns the information that was cached the last time the function was called with mode set to RegistrySettings.</summary>
        CurrentSettings = -1,
        /// <summary>Initializes and caches information about the display device.</summary>
        RegistrySettings = 0
    }

    [Flags]
    public enum EnumDisplaySettingsFlags : uint
    {
        /// <summary>Return all graphics modes reported by the adapter driver, regardless of monitor capabilities.</summary>
        RawMode = 0x00000002,
        /// <summary>Return graphics modes in all orientations.</summary>
        RotatedMode = 0x00000004,
    }

    [Flags]
    public enum ChangeDisplaySettingsFlags : uint
    {
        /// <summary>Default, the graphics mode for the current screen will be changed dynamically.</summary>
        Dynamic = 0x0,
        /// <summary>Like Dynamic, but the registry will also be updated.</summary>
        UpdateRegistry = 0x00000001,
        /// <summary>The system tests if the requested graphics mode could be set.</summary>
        Test = 0x00000002,
        /// <summary>The mode is temporary in nature. If you change to and from another desktop, this mode will not be reset.</summary>
        Fullscreen = 0x00000004,
        /// <summary>Supplement to UpdateRegistry. The settings will be saved in the global settings area so that they will affect all users on the machine. Otherwise, only the settings for the user are modified.</summary>
        Global = 0x00000008,
        /// <summary>This device will become the primary device.</summary>
        SetPrimary = 0x00000010,
        /// <summary>The settings will be saved in the registry, but will not take effect. This flag is only valid when specified with the UpdateRegistry flag.</summary>
        NoReset = 0x10000000,
        /// <summary>Same as Reset, specifically for use with ChangeDisplaySettingsEx</summary>
        ResetEx = 0x20000000,
        /// <summary>The settings should be changed, even if the requested settings are the same as the current settings.</summary>
        Reset = 0x40000000,

        // --- Below this line supported by ChangeDisplaySettingsEx only! ---

        /// <summary>Set VideoParameters based on DisplayChangeSettingsEx argument.</summary>
        VideoParameters = 0x00000020,
        // <summary>Enable settings changes to unsafe graphics modes.</summary>
        EnableUnsafeModes = 0x00000100,
        // <summary>Disable settings changes to unsafe graphics modes.</summary>
        DisableUnsafeMods = 0x00000200
    }

    // See WinUser.h from Windows SDK for windows internal definition
    public enum ChangeDisplaySettingsResult : int
    {
        DISP_CHANGE_SUCCESSFUL = 0,
        DISP_CHANGE_RESTART = 1,
        DISP_CHANGE_FAILED = -1,
        DISP_CHANGE_BADMODE = -2,
        DISP_CHANGE_NOTUPDATED = -3,
        DISP_CHANGE_BADFLAGS = -4,
        DISP_CHANGE_BADPARAM = -5,
        DISP_CHANGE_BADDUALVIEW = -6
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct VideoParameters {
        public Guid guid;
        [MarshalAs(UnmanagedType.U8)]
        public ulong dwOffset;
        [MarshalAs(UnmanagedType.U8)]
        public ulong dwCommand;
        [MarshalAs(UnmanagedType.U8)]
        public ulong dwFlags;
        [MarshalAs(UnmanagedType.U8)]
        public ulong dwMode;
        [MarshalAs(UnmanagedType.U8)]
        public ulong dwTVStandard;
        [MarshalAs(UnmanagedType.U8)]
        public ulong dwAvailableModes;
        [MarshalAs(UnmanagedType.U8)]
        public ulong dwAvailableTVStandard;
        [MarshalAs(UnmanagedType.U8)]
        public ulong dwFlickerFilter;
        [MarshalAs(UnmanagedType.U8)]
        public ulong dwOverScanX;
        [MarshalAs(UnmanagedType.U8)]
        public ulong dwOverScanY;
        [MarshalAs(UnmanagedType.U8)]
        public ulong dwMaxUnscaledX;
        [MarshalAs(UnmanagedType.U8)]
        public ulong dwMaxUnscaledY;
        [MarshalAs(UnmanagedType.U8)]
        public ulong dwPositionX;
        [MarshalAs(UnmanagedType.U8)]
        public ulong dwPositionY;
        [MarshalAs(UnmanagedType.U8)]
        public ulong dwBrightness;
        [MarshalAs(UnmanagedType.U8)]
        public ulong dwContrast;
        [MarshalAs(UnmanagedType.U8)]
        public ulong dwCPType;
        [MarshalAs(UnmanagedType.U8)]
        public ulong dwCPCommand;
        [MarshalAs(UnmanagedType.U8)]
        public ulong dwCPStandard;
        [MarshalAs(UnmanagedType.U8)]
        public ulong dwCPKey;
        [MarshalAs(UnmanagedType.U8)]
        public ulong bCP_APSTriggerBits;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=256)]
        public string bOEMCopyProtection;
    }
}
