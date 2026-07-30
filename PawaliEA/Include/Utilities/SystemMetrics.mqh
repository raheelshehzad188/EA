//+------------------------------------------------------------------+
//| PawaliEA Enterprise - System metrics collector                    |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_UTILITIES_SYSTEM_METRICS_MQH
#define PAWALI_EA_UTILITIES_SYSTEM_METRICS_MQH

class CPawaliSystemMetrics
{
public:
   static double GetCpuUsagePercent(void)
   {
      // MT5 does not expose native CPU metrics; placeholder for enterprise telemetry hook.
      return 0.0;
   }

   static double GetRamUsageMb(void)
   {
      return 0.0;
   }

   static int GetTerminalPingMs(void)
   {
      return (int)TerminalInfoInteger(TERMINAL_PING_LAST);
   }

   static int GetTerminalBuild(void)
   {
      return (int)TerminalInfoInteger(TERMINAL_BUILD);
   }

   static int GetMt5Build(void)
   {
      return (int)TerminalInfoInteger(TERMINAL_BUILD);
   }

   static string GetTerminalId(void)
   {
      return IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "@" + AccountInfoString(ACCOUNT_SERVER);
   }
};

#endif
