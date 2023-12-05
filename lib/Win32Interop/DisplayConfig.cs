using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

// Source: adapted from https://stackoverflow.com/questions/16082330/communicating-with-windows7-display-api
// TODO add explicit value type marshaling for everything in this class to be thorough
public class DisplayConfig
{
    // See WinUser.h from Windows SDK for windows internal method definition
    // See wingdi.h from Windows SDK for windows internal nested enum definitions
    // See generic win32 error codes for windows internal return val definiion
    [DllImport("User32.dll", CharSet = CharSet.Auto)]
    public static extern int GetDisplayConfigBufferSizes(
        QueryDisplayConfigFlags flags,
        ref uint numPathArrayElements,
        ref uint numModeInfoArrayElements
    );

    // See WinUser.h from Windows SDK for windows internal method definition
    // See wingdi.h from Windows SDK for windows internal nested enum definitions
    // See generic win32 error codes for windows internal return val definiion
    [DllImport("User32.dll", CharSet = CharSet.Auto)]
    private static extern int QueryDisplayConfig(
        // DatabaseCurrent not supported (since we can't marshal required CurrentTopologyId values for it)
        QueryDisplayConfigFlags flags, 
        ref uint numPathArrayElements,
        [Out] DisplayConfigPathInfo[] pathInfoArray, 
        ref uint modeInfoArrayElements,
        [Out] DisplayConfigModeInfo[] modeInfoArray,
        // The actual type is a nullable out DisplayConfigTopologyId only required if flags has DatabaseCurrent
        // An IntPtr can still be marshaled allowing us to pass something recognized as a null pointer
        // TODO support somehow passing an actual DisplayConfigTopologyId if needed (marshalas IsAny?)
        IntPtr currentTopologyId
    );

    // Wrapper to get around incompatibilities with more generic typing in powershell and make it clear topology id is not supported
    public static int QueryDisplayConfig(
        QueryDisplayConfigFlags flags,
        ref uint pathsCount,
        [In, Out] ref DisplayConfigPathInfo[] paths,
        ref uint modesCount,
        [In, Out] ref DisplayConfigModeInfo[] modes
    ) {
        paths = new DisplayConfigPathInfo[pathsCount];
        modes = new DisplayConfigModeInfo[modesCount];
        int result = QueryDisplayConfig(flags, ref pathsCount, paths, ref modesCount, modes, IntPtr.Zero);
        // QueryDisplayConfig may return more than predicted, truncate the array to the predicted size.
        Array.Resize(ref paths, (int)pathsCount);
        Array.Resize(ref modes, (int)modesCount);
        return result;
    }

    // See WinUser.h from Windows SDK for windows internal method definition
    // See generic win32 error codes for windows internal return val definiion
    [DllImport("User32.dll", CharSet = CharSet.Auto)]
    public static extern int DisplayConfigGetDeviceInfo(
        [In, Out] ref DisplayConfigTargetDeviceName targetDeviceName
    );

    [DllImport("User32.dll", CharSet = CharSet.Auto)]
    public static extern int DisplayConfigGetDeviceInfo(
        [In, Out] ref DisplayConfigGetAdvancedColorInfo getAdvancedColorInfo
    );

    [DllImport("User32.dll", CharSet = CharSet.Auto)]
    public static extern int DisplayConfigGetDeviceInfo(
        [In, Out] ref DisplayConfigTargetPreferredMode targetPreferredMode
    );

    [DllImport("User32.dll", CharSet = CharSet.Auto)]
    public static extern int DisplayConfigGetDeviceInfo(
        [In, Out] ref DisplayConfigAdapterName adapterName
    );

    [DllImport("User32.dll", CharSet = CharSet.Auto)]
    public static extern int DisplayConfigGetDeviceInfo(
        [In, Out] ref DisplayConfigSourceDeviceName sourceDeviceName
    );

    // TODO marshall and implement the below for logging purposes
    // [DllImport("User32.dll", CharSet = CharSet.Auto)]
    // public static extern int DisplayConfigGetDeviceInfo(
    //     [In, Out] ref DisplayConfigTargetAdapterName targetAdapterName
    // );

    // See WinUser.h from Windows SDK for windows internal method definition
    // See wingdi.h from Windows SDK for windows internal nested enum definitions
    // See generic win32 error codes for windows internal return val definiion
    [DllImport("User32.dll", CharSet = CharSet.Auto)]
    public static extern int SetDisplayConfig(
        uint numPathArrayElements, 
        [In] DisplayConfigPathInfo[] pathArray,
        uint numModeInfoArrayElements, 
        [In] DisplayConfigModeInfo[] modeInfoArray,
        SetDisplayConfigFlags flags
    );

    [DllImport("User32.dll", CharSet = CharSet.Auto)]
    public static extern int DisplayConfigSetDeviceInfo(
        [In, Out] ref DisplayConfigSetAdvancedColorInfo setAdvancedColorInfo
    );

    public enum DisplayConfigTopologyId : uint {
        DISPLAYCONFIG_TOPOLOGY_INTERNAL = 0x00000001,
        DISPLAYCONFIG_TOPOLOGY_CLONE = 0x00000002,
        DISPLAYCONFIG_TOPOLOGY_EXTEND = 0x00000004,
        DISPLAYCONFIG_TOPOLOGY_EXTERNAL = 0x00000008,
        DISPLAYCONFIG_TOPOLOGY_FORCE_UINT32 = 0xFFFFFFFF
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct LUID
    {
        public uint LowPart;
        public int HighPart;
    }

    [Flags]
    public enum DisplayConfigVideoOutputTechnology : uint {
        Other = 4294967295, // -1
        Hd15 = 0,
        Svideo = 1,
        CompositeVideo = 2,
        ComponentVideo = 3,
        Dvi = 4,
        Hdmi = 5,
        Lvds = 6,
        DJpn = 8,
        Sdi = 9,
        DisplayportExternal = 10,
        DisplayportEmbedded = 11,
        UdiExternal = 12,
        UdiEmbedded = 13,
        Sdtvdongle = 14,
        Internal = 0x80000000,
        ForceUint32 = 0xFFFFFFFF
    }

    [Flags]
    public enum SetDisplayConfigFlags : uint {
        None = 0x0,
        TopologyInternal = 0x00000001,
        TopologyClone = 0x00000002,
        TopologyExtend = 0x00000004,
        TopologyExternal = 0x00000008,
        TopologySupplied = 0x00000010,
        UseSuppliedDisplayConfig = 0x00000020,
        Validate = 0x00000040,
        Apply = 0x00000080,
        NoOptimization = 0x00000100,
        SaveToDatabase = 0x00000200,
        AllowChanges = 0x00000400,
        PathPersistIfRequired = 0x00000800,
        ForceModeEnumeration = 0x00001000,
        AllowPathOrderChanges = 0x00002000,
        UseDatabaseCurrent = TopologyInternal | TopologyClone | TopologyExtend | TopologyExternal
    }

    [Flags]
    public enum DisplayConfigSourceStatus : uint
    {
        None = 0x0,
        InUse = 0x00000001
    }

    [Flags]
    public enum DisplayConfigTargetStatus : uint
    {
        Nne = 0x0,
        InUse = 0x00000001,
        FORCIBLE = 0x00000002,
        ForcedAvailabilityBoot = 0x00000004,
        ForcedAvailabilityPath = 0x00000008,
        ForcedAvailabilitySystem = 0x00000010,
    }

    [Flags]
    public enum DisplayConfigRotation : uint
    {
        None = 0x0,
        Identity = 1,
        Rotate90 = 2,
        Rotate180 = 3,
        Rotate270 = 4,
        ForceUint32 = 0xFFFFFFFF
    }

    [Flags]
    public enum DisplayConfigPixelFormat : uint
    {
        None = 0x0,
        Pixelformat8Bpp = 1,
        Pixelformat16Bpp = 2,
        Pixelformat24Bpp = 3,
        Pixelformat32Bpp = 4,
        PixelformatNongdi = 5,
        PixelformatForceUint32 = 0xffffffff
    }

    [Flags]
    public enum DisplayConfigScaling : uint
    {
        None = 0x0, 
        Identity = 1,
        Centered = 2,
        Stretched = 3,
        Aspectratiocenteredmax = 4,
        Custom = 5,
        Preferred = 128,
        ForceUint32 = 0xFFFFFFFF
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DisplayConfigRational
    {
        public uint numerator;
        public uint denominator;
    }

    [Flags]
    public enum DisplayConfigScanLineOrdering : uint
    {
        Unspecified = 0,
        Progressive = 1,
        Interlaced = 2,
        InterlacedUpperfieldfirst = Interlaced,
        InterlacedLowerfieldfirst = 3,
        ForceUint32 = 0xFFFFFFFF
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DisplayConfigPathInfo
    {
        public DisplayConfigPathSourceInfo sourceInfo;
        public DisplayConfigPathTargetInfo targetInfo;
        public DisplayConfigPathInfoFlags flags;
    }

    [Flags]
    public enum DisplayConfigPathInfoFlags : uint
    {
        None = 0x0,
        PathActive = 0x00000001,
        PathSupportVirtualMode = 0x00000008,
        PathBoostRefreshRate = 0x00000010
    }

    [Flags]
    public enum DisplayConfigModeInfoType : uint
    {
        None = 0x0,
        Source = 1,
        Target = 2,
        ForceUint32 = 0xFFFFFFFF
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct DisplayConfigModeInfo
    {
        [FieldOffset((0))]
        public DisplayConfigModeInfoType infoType;
        [FieldOffset(4)]
        public uint id;
        [FieldOffset(8)]
        public LUID adapterId;
        [FieldOffset(16)]
        public DisplayConfigTargetMode targetMode;
        [FieldOffset(16)]
        public DisplayConfigSourceMode sourceMode;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DisplayConfig2DRegion
    {
        public uint cx;
        public uint cy;
    }

    [Flags]
    public enum D3DmdtVideoSignalStandard : uint
    {
        Uninitialized = 0,
        VesaDmt = 1,
        VesaGtf = 2,
        VesaCvt = 3,
        Ibm = 4,
        Apple = 5,
        NtscM = 6,
        NtscJ = 7,
        Ntsc443 = 8,
        PalB = 9,
        PalB1 = 10,
        PalG = 11,
        PalH = 12,
        PalI = 13,
        PalD = 14,
        PalN = 15,
        PalNc = 16,
        SecamB = 17,
        SecamD = 18,
        SecamG = 19,
        SecamH = 20,
        SecamK = 21,
        SecamK1 = 22,
        SecamL = 23,
        SecamL1 = 24,
        Eia861 = 25,
        Eia861A = 26,
        Eia861B = 27,
        PalK = 28,
        PalK1 = 29,
        PalL = 30,
        PalM = 31,
        Other = 255
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DisplayConfigVideoSignalInfo
    {
        public long pixelRate;
        public DisplayConfigRational hSyncFreq;
        public DisplayConfigRational vSyncFreq;
        public DisplayConfig2DRegion activeSize;
        public DisplayConfig2DRegion totalSize;
        public D3DmdtVideoSignalStandard videoStandard;
        public DisplayConfigScanLineOrdering ScanLineOrdering;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DisplayConfigTargetMode
    {
        public DisplayConfigVideoSignalInfo targetVideoSignalInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PointL
    {
        public long x;
        public long y;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DisplayConfigSourceMode
    {
        public uint width;
        public uint height;
        public DisplayConfigPixelFormat pixelFormat;
        public PointL position;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DisplayConfigPathSourceInfo
    {
        public LUID adapterId;
        public uint id;
        public uint modeInfoIdx;
        public DisplayConfigSourceStatus statusFlags;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DisplayConfigPathTargetInfo
    {
        public LUID adapterId;
        public uint id;
        public uint modeInfoIdx;
        public DisplayConfigVideoOutputTechnology outputTechnology; 
        public DisplayConfigRotation rotation;
        public DisplayConfigScaling scaling;
        public DisplayConfigRational refreshRate;
        public DisplayConfigScanLineOrdering scanLineOrdering;
        public bool targetAvailable;
        public DisplayConfigTargetStatus statusFlags;
    }

    [Flags]
    public enum QueryDisplayConfigFlags : uint
    {
        None = 0x0,
        AllPaths = 0x00000001,
        OnlyActivePaths = 0x00000002,
        DatabaseCurrent = 0x00000004
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DisplayConfigDeviceInfoHeader
    {
        public DisplayConfigDeviceInfoType type;
        public uint size;
        public LUID adapterId;
        public uint id;
    }

    public enum DisplayConfigDeviceInfoType : uint
    {
        DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME = 1,
        DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME = 2,
        DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_PREFERRED_MODE = 3,
        DISPLAYCONFIG_DEVICE_INFO_GET_ADAPTER_NAME = 4,
        DISPLAYCONFIG_DEVICE_INFO_SET_TARGET_PERSISTENCE = 5,
        DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_BASE_TYPE = 6,
        DISPLAYCONFIG_DEVICE_INFO_GET_SUPPORT_VIRTUAL_RESOLUTION = 7,
        DISPLAYCONFIG_DEVICE_INFO_SET_SUPPORT_VIRTUAL_RESOLUTION = 8,
        DISPLAYCONFIG_DEVICE_INFO_GET_ADVANCED_COLOR_INFO = 9,
        DISPLAYCONFIG_DEVICE_INFO_SET_ADVANCED_COLOR_STATE = 10,
        DISPLAYCONFIG_DEVICE_INFO_GET_SDR_WHITE_LEVEL = 11,
        DISPLAYCONFIG_DEVICE_INFO_FORCE_UINT32 = 0xFFFFFFFF
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DisplayConfigSourceDeviceName
    {
        public DisplayConfigDeviceInfoHeader header;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string viewGdiDeviceName; 
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DisplayConfigAdapterName
    {
        public DisplayConfigDeviceInfoHeader header;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string adapterDevicePath;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DisplayConfigTargetDeviceName
    {
        public DisplayConfigDeviceInfoHeader header;
        public DisplayConfigTargetDeviceNameFlags flags;
        public DisplayConfigVideoOutputTechnology outputTechnology;
        public ushort edidManufacturerId;
        public ushort edidProductCodeId;
        public uint connectorInstance;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
        public string monitorFriendlyDeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string monitorDevicePath;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DisplayConfigTargetDeviceNameFlags {
        public DisplayConfigTargetDeviceNameFlagValue value;
    }

    [Flags]

    public enum DisplayConfigTargetDeviceNameFlagValue : uint
    {
        FRIENDLY_NAME_FROM_EDID = 0x00000001,
        FRIENDLY_NAME_FORCED = 0x00000002,
        EDID_IS_VALID = 0x00000004,
        RESERVED = 0xFFFFFFF8
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DisplayConfigTargetPreferredMode
    {
        public DisplayConfigDeviceInfoHeader header;
        public uint width;
        public uint height;
        public DisplayConfigTargetMode targetMode;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct DisplayConfigGetAdvancedColorInfo
    {
        public DisplayConfigDeviceInfoHeader header;
        public DisplayConfigGetAdvancedColorInfoValues values;
        public DisplayConfigColorEncoding colorEncoding;
        public int bitsPerColorChannel;
    }

    [Flags]
    public enum DisplayConfigGetAdvancedColorInfoValues : uint {
        // A type of advanced color is supported
        AdvancedColorSupported = 0x1,
        // A type of advanced color is enabled
        AdvancedColorEnabled = 0x2,
        // Wide color gamut is enabled
        WideColorEnforced = 0x4,
        // Advanced color is force disabled due to system/OS policy
        AdvancedColorForceDisabled = 0x8
    }

    public enum DisplayConfigColorEncoding : uint
    {
        DISPLAYCONFIG_COLOR_ENCODING_RGB = 0,
        DISPLAYCONFIG_COLOR_ENCODING_YCBCR444 = 1,
        DISPLAYCONFIG_COLOR_ENCODING_YCBCR422 = 2,
        DISPLAYCONFIG_COLOR_ENCODING_YCBCR420 = 3,
        DISPLAYCONFIG_COLOR_ENCODING_INTENSITY = 4,
    }
    
    [StructLayout(LayoutKind.Sequential)]
    public struct DisplayConfigSetAdvancedColorInfo
    {
        public DisplayConfigDeviceInfoHeader header;
        public DisplayConfigSetAdvancedColorInfoValues values;
    }

    [Flags]
    public enum DisplayConfigSetAdvancedColorInfoValues : uint
    {
        EnableAdvancedColor = 0x1
    }
}
