//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Authentication interface                    |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_INTERFACES_I_AUTHENTICATABLE_MQH
#define PAWALI_EA_INTERFACES_I_AUTHENTICATABLE_MQH

#include "../Models/AuthModels.mqh"

class IPawaliAuthenticatable
{
public:
   virtual bool Authenticate(SPawaliAuthResponse &response) = 0;
   virtual bool RefreshToken(SPawaliAuthResponse &response) = 0;
   virtual bool HasValidToken(void) const = 0;
   virtual string GetAccessToken(void) const = 0;
};

#endif
