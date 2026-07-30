//+------------------------------------------------------------------+
//| PawaliEA Enterprise - License models                              |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_MODELS_LICENSE_MODELS_MQH
#define PAWALI_EA_MODELS_LICENSE_MODELS_MQH

#include "../Enums/ConnectionStatus.mqh"

struct SPawaliLicenseInfo
{
   ENUM_PAWALI_LICENSE_STATUS status;
   string licenseKey;
   datetime expiresAt;
   string owner;
   string message;
   bool   isValid;
};

#endif
