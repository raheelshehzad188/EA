//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Connection and license status               |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_ENUMS_CONNECTION_STATUS_MQH
#define PAWALI_EA_ENUMS_CONNECTION_STATUS_MQH

enum ENUM_PAWALI_CONNECTION_STATUS
{
   PAWALI_CONN_DISCONNECTED = 0,
   PAWALI_CONN_CONNECTING   = 1,
   PAWALI_CONN_ONLINE       = 2,
   PAWALI_CONN_OFFLINE      = 3,
   PAWALI_CONN_DEGRADED     = 4
};

enum ENUM_PAWALI_LICENSE_STATUS
{
   PAWALI_LICENSE_UNKNOWN  = 0,
   PAWALI_LICENSE_VALID    = 1,
   PAWALI_LICENSE_EXPIRED  = 2,
   PAWALI_LICENSE_INVALID  = 3,
   PAWALI_LICENSE_REVOKED  = 4
};

enum ENUM_PAWALI_API_STATUS
{
   PAWALI_API_IDLE      = 0,
   PAWALI_API_BUSY      = 1,
   PAWALI_API_ERROR     = 2,
   PAWALI_API_RETRYING  = 3
};

inline string PawaliConnectionStatusLabel(const ENUM_PAWALI_CONNECTION_STATUS status)
{
   switch(status)
   {
      case PAWALI_CONN_CONNECTING: return "CONNECTING";
      case PAWALI_CONN_ONLINE:     return "ONLINE";
      case PAWALI_CONN_OFFLINE:    return "OFFLINE";
      case PAWALI_CONN_DEGRADED:   return "DEGRADED";
      default:                     return "DISCONNECTED";
   }
}

inline string PawaliLicenseStatusLabel(const ENUM_PAWALI_LICENSE_STATUS status)
{
   switch(status)
   {
      case PAWALI_LICENSE_VALID:   return "VALID";
      case PAWALI_LICENSE_EXPIRED: return "EXPIRED";
      case PAWALI_LICENSE_INVALID: return "INVALID";
      case PAWALI_LICENSE_REVOKED: return "REVOKED";
      default:                     return "UNKNOWN";
   }
}

#endif
