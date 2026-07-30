//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Heartbeat payload model                     |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_MODELS_HEARTBEAT_MODELS_MQH
#define PAWALI_EA_MODELS_HEARTBEAT_MODELS_MQH

struct SPawaliHeartbeatPayload
{
   double   balance;
   double   equity;
   double   margin;
   double   freeMargin;
   double   floatingProfit;
   double   currentDrawdown;
   string   broker;
   string   server;
   string   eaVersion;
   int      mt5Build;
   ulong    magicNumber;
   int      terminalBuild;
   double   spread;
   int      pingMs;
   double   cpuUsage;
   double   ramUsage;
   string   strategyVersion;
   string   currentSymbol;
   int      openTrades;
   datetime sentAt;
};

#endif
