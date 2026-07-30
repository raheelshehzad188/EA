//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Authentication models                       |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_MODELS_AUTH_MODELS_MQH
#define PAWALI_EA_MODELS_AUTH_MODELS_MQH

struct SPawaliAuthRequest
{
   string licenseKey;
   string accountNumber;
   string eaVersion;
};

struct SPawaliAuthResponse
{
   bool   success;
   string accessToken;
   string refreshToken;
   datetime expiresAt;
   string message;
   int    httpStatus;
};

struct SPawaliTokenBundle
{
   string   accessToken;
   string   refreshToken;
   datetime expiresAt;
   bool     isValid;
};

#endif
