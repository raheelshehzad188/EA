//+------------------------------------------------------------------+
//| PawaliEA Enterprise - API configuration model                     |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_MODELS_API_CONFIG_MQH
#define PAWALI_EA_MODELS_API_CONFIG_MQH

struct SPawaliApiConfig
{
   string baseUrl;
   int    timeoutMs;
   int    maxRetries;
   int    retryDelayMs;
   int    heartbeatIntervalSec;
   int    commandPollIntervalSec;
   int    syncIntervalSec;
   int    tokenRefreshBufferSec;
   int    maxQueueAttempts;
   int    maxQueueItems;
   string licenseKey;
   ulong  magicNumber;
   string strategyVersion;
   string eaVersion;
};

#endif
