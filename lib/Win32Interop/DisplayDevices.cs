using System;
using System.Runtime.InteropServices;

// Source: adapted from https://pinvoke.net/
public class DisplayDevices
{
    // See WinUser.h from Windows SDK for windows internal method definition
    // See generic win32 error codes for windows internal return val definiion
    // TODO return actual generic error enum instead of int? find clean way to safe cast it. same goes for other structures
    [DllImport("User32.dll", CharSet = CharSet.Unicode)]
    public static extern bool EnumDisplayDevices(
        [param: MarshalAs(UnmanagedType.LPWStr)] 
        string deviceName,
        [param: MarshalAs(UnmanagedType.U4)]
        uint deviceIndex,
        [In, Out] ref DisplayDevice displayDevice,
        [param: MarshalAs(UnmanagedType.U4)] 
        EnumDisplayDevicesFlags flags
    );

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct DisplayDevice
    {
      [MarshalAs(UnmanagedType.U4)]
      public uint cb;
      [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)]
      public string DeviceName;
      [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)]
      public string DeviceString;
      [MarshalAs(UnmanagedType.U4)]
      public DisplayDeviceStateFlags StateFlags;
      [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)]
      public string DeviceID;
      [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)]
      public string DeviceKey;
    }

    [Flags]
    public enum DisplayDeviceStateFlags : int
    {
        /// <summary>Specifies whether a monitor is presented as being "on" by the respective GDI view.</summary>
        DeviceActive = 0x1,
        /// <summary>The device is the primary display device for the desktop.</summary>
        PrimaryDevice = 0x4,
        /// <summary>Represents a pseudo device used to mirror application drawing for remoting or other purposes.</summary>
        MirroringDriver = 0x8,
        /// <summary>The device is VGA compatible.</summary>
        VGACompatible = 0x10,
        /// <summary>The device is removable; it cannot be the primary display.</summary>
        Removable = 0x20,
        /// <summary>The device has more display modes than its output devices support.</summary>
        ModesPruned = 0x8000000,
        Remote = 0x4000000,
        Disconnect = 0x2000000
    }

    [Flags()]
    public enum EnumDisplayDevicesFlags : uint
    {
        None = 0x0,
        /// <summary>Retrieve the device interface name for GUID_DEVINTERFACE_MONITOR, which is registered by the operating system on a per monitor basis.</summary>
        GetDeviceInterfaceName = 0x00000001
    }
}
