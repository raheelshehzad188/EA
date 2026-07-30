//+------------------------------------------------------------------+
//| PawaliEA Enterprise - HTTP transport interface                    |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_INTERFACES_I_API_TRANSPORT_MQH
#define PAWALI_EA_INTERFACES_I_API_TRANSPORT_MQH

#include "../Enums/SyncStatus.mqh"

struct SPawaliHttpResponse
{
   bool   success;
   int    statusCode;
   string body;
   string errorMessage;
   int    latencyMs;
};

class IPawaliApiTransport
{
public:
   virtual bool Send(const ENUM_PAWALI_HTTP_METHOD method,
                     const string endpoint,
                     const string payloadJson,
                     const string bearerToken,
                     SPawaliHttpResponse &response) = 0;
};

#endif
