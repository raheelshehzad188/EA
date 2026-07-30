//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Remote settings model                       |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_MODELS_SETTINGS_MODELS_MQH
#define PAWALI_EA_MODELS_SETTINGS_MODELS_MQH

struct SPawaliRemoteSettings
{
   int    version;
   bool   tradingEnabled;
   bool   buyEnabled;
   bool   sellEnabled;
   double riskPercent;
   int    maxSpreadPoints;
   string strategyVersion;
   datetime updatedAt;
   bool   isLoaded;
};

#endif
