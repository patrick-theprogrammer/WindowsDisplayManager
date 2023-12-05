// Title: An exhaustive enum of all Windows System Error Codes 
// Source: Adapted from https://msdn.microsoft.com/en-us/library/windows/desktop/ms681381.aspx
// Description: Error codes are a means to provide information to outside systems on why a program terminated. This list
// need not be included in its entirety. It is meant to aid in conforming to the existing error code usage.
// See this link form more information on usage. https://msdn.microsoft.com/en-us/library/system.environment.exitcode.aspx
// Note: Internet error codes are excluded from this list. See here: https://msdn.microsoft.com/en-us/library/windows/desktop/aa385465.aspx
// Updated: 2016/10/31
public enum Win32Error : int
{
    ERROR_SUCCESS = 0, // (0x0) The operation completed successfully.
    ERROR_ACCESS_DENIED = 5, // (0x5) Access is denied.
    ERROR_GEN_FAILURE = 31, // (0x1F) A device attached to the system is not functioning. May indicate an unspecified error has occurred.
    ERROR_NOT_SUPPORTED = 50, // (0x32) The request is not supported.
    ERROR_INVALID_PARAMETER = 87, // (0x57) The parameter is incorrect.
    ERROR_INSUFFICIENT_BUFFER = 122, // (0x7A) The data area passed to a system call is too small.
    ERROR_BAD_CONFIGURATION = 1610 // (0x64A) The configuration data for this product is corrupt. Contact your support personnel.
}
