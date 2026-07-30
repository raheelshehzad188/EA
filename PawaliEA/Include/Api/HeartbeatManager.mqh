//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Heartbeat manager                           |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_API_HEARTBEAT_MANAGER_MQH
#define PAWALI_EA_API_HEARTBEAT_MANAGER_MQH

#include "../Models/HeartbeatModels.mqh"
#include "../Models/ApiConfig.mqh"
#include "../Models/OperationResult.mqh"
#include "AuthenticationManager.mqh"
#include "OfflineQueueManager.mqh"
#include "../Core/SettingsManager.mqh"
#include "../Enums/ApiEndpoints.mqh"
#include "../Utilities/JsonSerializer.mqh"
#include "../Utilities/SystemMetrics.mqh"
#include "../Logs/Logger.mqh"

class CPawaliHeartbeatManager
{
private:
   CPawaliAuthenticationManager *m_auth;
   CPawaliOfflineQueueManager   *m_queue;
   CPawaliSettingsManager       *m_settings;
   CPawaliLogger                *m_logger;
   SPawaliApiConfig              m_config;
   datetime                      m_lastSentAt;
   int                           m_successCount;
   int                           m_failureCount;
   int                           m_consecutiveFailures;

   double CalculateDrawdown(void) const
   {
      const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      const double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
      if(balance <= 0.0)
         return 0.0;
      return MathMax(0.0, (balance - equity) / balance);
   }

   int CountOpenTrades(void) const
   {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC) != m_config.magicNumber)
            continue;
         count++;
      }
      return count;
   }

   string ResolveStrategyVersion(void) const
   {
      if(m_settings != NULL)
      {
         const SPawaliRemoteSettings settings = m_settings.GetSettingsCopy();
         if(settings.strategyVersion != "")
            return settings.strategyVersion;
      }
      return m_config.strategyVersion;
   }

   SPawaliHeartbeatPayload BuildPayload(void) const
   {
      SPawaliHeartbeatPayload payload;
      payload.balance          = AccountInfoDouble(ACCOUNT_BALANCE);
      payload.equity           = AccountInfoDouble(ACCOUNT_EQUITY);
      payload.margin           = AccountInfoDouble(ACCOUNT_MARGIN);
      payload.freeMargin       = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      payload.floatingProfit   = AccountInfoDouble(ACCOUNT_PROFIT);
      payload.currentDrawdown  = CalculateDrawdown();
      payload.broker           = AccountInfoString(ACCOUNT_COMPANY);
      payload.server           = AccountInfoString(ACCOUNT_SERVER);
      payload.eaVersion        = m_config.eaVersion;
      payload.mt5Build         = CPawaliSystemMetrics::GetMt5Build();
      payload.magicNumber      = m_config.magicNumber;
      payload.terminalBuild    = CPawaliSystemMetrics::GetTerminalBuild();
      payload.spread           = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      payload.pingMs           = CPawaliSystemMetrics::GetTerminalPingMs();
      payload.cpuUsage         = CPawaliSystemMetrics::GetCpuUsagePercent();
      payload.ramUsage         = CPawaliSystemMetrics::GetRamUsageMb();
      payload.strategyVersion  = ResolveStrategyVersion();
      payload.currentSymbol    = _Symbol;
      payload.openTrades       = CountOpenTrades();
      payload.sentAt           = TimeCurrent();
      return payload;
   }

   void QueuePayload(const SPawaliHeartbeatPayload &payload)
   {
      if(m_queue == NULL)
         return;

      const string body = CPawaliJsonSerializer::SerializeHeartbeat(payload);
      m_queue.Enqueue(PAWALI_QUEUE_HEARTBEAT,
                      PAWALI_HTTP_POST,
                      PAWALI_API_HEARTBEAT,
                      body,
                      StringFormat("heartbeat-%I64u", (ulong)payload.sentAt));
   }

public:
   CPawaliHeartbeatManager(void) :
      m_auth(NULL),
      m_queue(NULL),
      m_settings(NULL),
      m_logger(NULL),
      m_lastSentAt(0),
      m_successCount(0),
      m_failureCount(0),
      m_consecutiveFailures(0)
   {}

   void Init(CPawaliAuthenticationManager *auth,
             CPawaliOfflineQueueManager *queue,
             CPawaliSettingsManager *settings,
             CPawaliLogger *logger,
             const SPawaliApiConfig &config)
   {
      m_auth     = auth;
      m_queue    = queue;
      m_settings = settings;
      m_logger   = logger;
      m_config   = config;
   }

   datetime GetLastSentAt(void) const { return m_lastSentAt; }
   int GetSuccessCount(void) const { return m_successCount; }
   int GetFailureCount(void) const { return m_failureCount; }
   int GetConsecutiveFailures(void) const { return m_consecutiveFailures; }

   ENUM_PAWALI_OPERATION_RESULT SendHeartbeat(void)
   {
      if(m_auth == NULL)
         return PAWALI_OP_FAILED;

      const SPawaliHeartbeatPayload payload = BuildPayload();
      const string body = CPawaliJsonSerializer::SerializeHeartbeat(payload);
      const string dedupe = StringFormat("heartbeat-%I64u", (ulong)payload.sentAt);

      SPawaliHttpResponse response;
      if(!m_auth.ExecuteAuthorizedRequest(PAWALI_HTTP_POST, PAWALI_API_HEARTBEAT, body,
                                           dedupe, response))
      {
         m_failureCount++;
         m_consecutiveFailures++;
         QueuePayload(payload);
         if(m_logger != NULL)
            m_logger.ApiWarn(StringFormat("Heartbeat failed (%d consecutive): %s",
                                          m_consecutiveFailures,
                                          response.errorMessage));
         return PAWALI_OP_OFFLINE_QUEUED;
      }

      m_lastSentAt            = TimeCurrent();
      m_successCount++;
      m_consecutiveFailures   = 0;
      if(m_logger != NULL)
         m_logger.ApiInfo("Heartbeat sent.");
      return PAWALI_OP_SUCCEEDED;
   }
};

#endif
