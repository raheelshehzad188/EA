//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Application orchestrator                    |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_CORE_APPLICATION_MQH
#define PAWALI_EA_CORE_APPLICATION_MQH

#include "../Models/ApiConfig.mqh"
#include "../Models/OperationResult.mqh"
#include "../Logs/Logger.mqh"
#include "../Api/ApiClient.mqh"
#include "../Api/AuthenticationManager.mqh"
#include "../Api/HeartbeatManager.mqh"
#include "../Api/CommandManager.mqh"
#include "../Api/OfflineQueueManager.mqh"
#include "SettingsManager.mqh"
#include "LicenseManager.mqh"
#include "TradeSyncManager.mqh"
#include "DecisionSyncManager.mqh"
#include "MarketDataCollector.mqh"
#include "TimerManager.mqh"
#include "Diagnostics.mqh"
#include "DebugPanel.mqh"
#include "../Trading/TradingEngine.mqh"
#include "../Enums/ConnectionStatus.mqh"

#define PAWALI_EA_VERSION "1.0.0"

input group "=== PawaliEA Enterprise ==="
input string InpApiBaseUrl        = "http://38.84.24.79:8005/api"; // Laravel API base URL
input string InpLicenseKey        = "";                         // License key
input string InpApiKey            = "";                         // API key
input string InpApiSecret         = "";                         // API secret
input ulong  InpMagicNumber       = 20260730;                   // Magic number
input string InpStrategyVersion   = "0.0.0";                    // Strategy version
input int    InpApiTimeoutMs      = 10000;                      // API timeout (ms)
input int    InpApiMaxRetries     = 3;                          // API max retries
input int    InpApiRetryDelayMs   = 2000;                       // Retry delay (ms)
input bool   InpShowDebugPanel    = true;                       // Show debug panel

class CPawaliApplication
{
private:
   CPawaliLogger                  m_logger;
   CPawaliApiClient               m_apiClient;
   CPawaliAuthenticationManager   m_authManager;
   CPawaliOfflineQueueManager     m_offlineQueue;
   CPawaliSettingsManager         m_settingsManager;
   CPawaliLicenseManager          m_licenseManager;
   CPawaliHeartbeatManager        m_heartbeatManager;
   CPawaliCommandManager          m_commandManager;
   CPawaliTradeSyncManager        m_tradeSyncManager;
   CPawaliDecisionSyncManager     m_decisionSyncManager;
   CPawaliMarketDataCollector     m_marketData;
   CPawaliTimerManager            m_timerManager;
   CPawaliDiagnostics             m_diagnostics;
   CPawaliDebugPanel              m_debugPanel;
   CPawaliTradingEngine           m_tradingEngine;

   SPawaliApiConfig               m_config;
   ENUM_PAWALI_CONNECTION_STATUS  m_connectionStatus;
   datetime                       m_lastHeartbeatRun;
   datetime                       m_lastCommandRun;
   datetime                       m_lastSyncRun;
   bool                           m_initialized;

   SPawaliApiConfig BuildConfig(void) const
   {
      SPawaliApiConfig config;
      config.baseUrl                = InpApiBaseUrl;
      config.timeoutMs              = InpApiTimeoutMs;
      config.maxRetries             = InpApiMaxRetries;
      config.retryDelayMs           = InpApiRetryDelayMs;
      config.heartbeatIntervalSec   = 60;
      config.commandPollIntervalSec = 15;
      config.syncIntervalSec        = 30;
      config.tokenRefreshBufferSec  = 120;
      config.maxQueueAttempts       = 10;
      config.maxQueueItems          = 1000;
      config.licenseKey             = InpLicenseKey;
      config.apiKey                 = InpApiKey;
      config.apiSecret              = InpApiSecret;
      config.magicNumber            = InpMagicNumber;
      config.strategyVersion        = InpStrategyVersion;
      config.eaVersion              = PAWALI_EA_VERSION;
      return config;
   }

   void ApplyLatestSettings(void)
   {
      const SPawaliRemoteSettings settings = m_settingsManager.GetSettingsCopy();
      m_tradingEngine.ApplySettings(settings);
      m_logger.ExpertInfo(StringFormat("Settings applied. Version=%d Strategy=%s",
                                       settings.version,
                                       settings.strategyVersion));
   }

   SPawaliDiagnosticsSnapshot BuildDiagnosticsSnapshot(void) const
   {
      SPawaliDiagnosticsSnapshot snapshot;
      const SPawaliRemoteSettings settings = m_settingsManager.GetSettingsCopy();
      const CPawaliCommandManager::SCommandContext context = m_commandManager.GetContext();

      snapshot.connectionStatus       = m_connectionStatus;
      snapshot.licenseStatus          = m_licenseManager.GetLicenseCopy().status;
      snapshot.apiStatus              = m_apiClient.GetStatus();
      snapshot.tradeSyncStatus        = m_tradeSyncManager.GetStatus();
      snapshot.decisionSyncStatus     = m_decisionSyncManager.GetStatus();
      snapshot.strategyVersion        = settings.strategyVersion;
      snapshot.lastHeartbeatAt        = m_heartbeatManager.GetLastSentAt();
      snapshot.lastSettingsDownloadAt = m_settingsManager.GetLastDownloadAt();
      snapshot.lastTradeSyncAt        = m_tradeSyncManager.GetLastSyncTime();
      snapshot.lastDecisionSyncAt     = m_decisionSyncManager.GetLastSyncTime();
      snapshot.pendingQueueCount      = m_offlineQueue.GetPendingCount();
      snapshot.queueReplayCount       = m_offlineQueue.GetReplayCount();
      snapshot.apiFailureStreak       = m_apiClient.GetConsecutiveFailures();
      snapshot.heartbeatFailures      = m_heartbeatManager.GetConsecutiveFailures();
      snapshot.authRefreshCount       = m_authManager.GetRefreshCount();
      snapshot.commandPollCount       = m_commandManager.GetPollCount();
      snapshot.settingsDownloadCount  = m_settingsManager.GetDownloadCount();
      snapshot.tradingPaused          = context.tradingPaused;
      snapshot.lastError              = m_settingsManager.GetLastError();
      return snapshot;
   }

   void UpdateConnectionStatus(const bool online)
   {
      if(online)
      {
         m_connectionStatus = PAWALI_CONN_ONLINE;
         return;
      }

      if(m_offlineQueue.GetPendingCount() > 0)
         m_connectionStatus = PAWALI_CONN_DEGRADED;
      else
         m_connectionStatus = PAWALI_CONN_OFFLINE;
   }

   bool RunSyncCycle(void)
   {
      SPawaliAuthResponse authResponse;
      const bool tokenOk = m_authManager.EnsureToken(authResponse);

      if(tokenOk)
      {
         m_offlineQueue.Flush();
         UpdateConnectionStatus(true);
      }
      else
      {
         UpdateConnectionStatus(false);
         m_diagnostics.SetLastError("Token refresh failed during sync cycle.");
      }

      m_tradeSyncManager.Sync();
      m_decisionSyncManager.Sync();

      const ENUM_PAWALI_OPERATION_RESULT settingsResult =
         m_settingsManager.DownloadSettings(false);

      if(settingsResult == PAWALI_OP_SUCCEEDED)
         ApplyLatestSettings();

      m_lastSyncRun = TimeCurrent();
      return tokenOk;
   }

public:
   CPawaliApplication(void) :
      m_connectionStatus(PAWALI_CONN_DISCONNECTED),
      m_lastHeartbeatRun(0),
      m_lastCommandRun(0),
      m_lastSyncRun(0),
      m_initialized(false)
   {}

   int Initialize(void)
   {
      m_config = BuildConfig();
      m_logger.Init("PawaliEA/Logs");
      m_logger.ExpertInfo("PawaliEA Enterprise foundation boot started.");

      m_apiClient.Init(m_config, GetPointer(m_logger));
      m_authManager.Init(GetPointer(m_apiClient), GetPointer(m_logger), m_config);
      m_offlineQueue.Init(GetPointer(m_authManager), GetPointer(m_logger),
                          m_config.maxQueueAttempts, m_config.maxQueueItems);
      m_settingsManager.Init(GetPointer(m_authManager), GetPointer(m_logger));
      m_licenseManager.Init(GetPointer(m_logger), m_config);
      m_heartbeatManager.Init(GetPointer(m_authManager), GetPointer(m_offlineQueue),
                              GetPointer(m_settingsManager), GetPointer(m_logger), m_config);
      m_commandManager.Init(GetPointer(m_authManager), GetPointer(m_offlineQueue), GetPointer(m_logger));
      m_tradeSyncManager.Init(GetPointer(m_authManager), GetPointer(m_offlineQueue), GetPointer(m_logger));
      m_decisionSyncManager.Init(GetPointer(m_authManager), GetPointer(m_offlineQueue), GetPointer(m_logger));
      m_marketData.Init(_Symbol);
      m_timerManager.Configure(m_config.heartbeatIntervalSec,
                               m_config.commandPollIntervalSec,
                               m_config.syncIntervalSec);
      m_diagnostics.Init(GetPointer(m_logger), 60);
      m_debugPanel.SetEnabled(InpShowDebugPanel);
      m_tradingEngine.Init(GetPointer(m_logger));

      if(!m_licenseManager.Validate())
         return INIT_FAILED;

      m_connectionStatus = PAWALI_CONN_CONNECTING;
      SPawaliAuthResponse authResponse;
      if(!m_authManager.Authenticate(authResponse))
      {
         m_logger.Error("Authentication failed. Continuing in offline/degraded mode.");
         m_diagnostics.SetLastError(authResponse.message);
         UpdateConnectionStatus(false);
      }
      else
      {
         m_licenseManager.ApplyServerLicenseState(true, authResponse.expiresAt);
         UpdateConnectionStatus(true);
      }

      const ENUM_PAWALI_OPERATION_RESULT settingsResult =
         m_settingsManager.DownloadSettings(true);

      if(settingsResult == PAWALI_OP_SUCCEEDED || settingsResult == PAWALI_OP_NO_CHANGES)
         ApplyLatestSettings();
      else if(settingsResult == PAWALI_OP_OFFLINE_QUEUED)
         m_logger.ExpertWarn("Started with cached settings due to API unavailability.");

      m_timerManager.StartAll();
      m_tradingEngine.Start();

      m_lastHeartbeatRun = 0;
      m_lastCommandRun     = 0;
      m_lastSyncRun        = 0;
      m_initialized        = true;

      m_logger.ExpertInfo("PawaliEA Enterprise foundation layer ready.");
      return INIT_SUCCEEDED;
   }

   void Shutdown(const int reason)
   {
      m_timerManager.StopAll();
      m_tradingEngine.Stop();
      m_debugPanel.Clear();
      m_logger.ExpertInfo(StringFormat("Shutdown complete. Reason=%d", reason));
      m_initialized = false;
   }

   void ProcessTick(void)
   {
      if(!m_initialized)
         return;

      m_tradingEngine.OnTick();

      if(m_commandManager.GetContext().restartRequested)
         m_logger.ExpertInfo("Restart command acknowledged.");

      if(m_commandManager.GetContext().forceSettingsSync)
      {
         if(m_settingsManager.DownloadSettings(true) == PAWALI_OP_SUCCEEDED)
            ApplyLatestSettings();
         m_commandManager.ClearTransientFlags();
      }

      SPawaliDiagnosticsSnapshot snapshot = BuildDiagnosticsSnapshot();
      m_diagnostics.LogSnapshot(snapshot);
      m_diagnostics.LogHealthAlert(snapshot);
      m_debugPanel.Render(snapshot);
   }

   void ProcessTimer(void)
   {
      if(!m_initialized)
         return;

      if(m_timerManager.ShouldRunHeartbeat(m_lastHeartbeatRun))
      {
         const ENUM_PAWALI_OPERATION_RESULT hbResult = m_heartbeatManager.SendHeartbeat();
         UpdateConnectionStatus(hbResult == PAWALI_OP_SUCCEEDED);
         m_lastHeartbeatRun = TimeCurrent();
      }

      if(m_timerManager.ShouldRunCommands(m_lastCommandRun))
      {
         m_commandManager.PollCommands();

         if(m_commandManager.GetContext().forceSettingsSync)
         {
            if(m_settingsManager.DownloadSettings(true) == PAWALI_OP_SUCCEEDED)
               ApplyLatestSettings();
            m_commandManager.ClearTransientFlags();
         }

         m_lastCommandRun = TimeCurrent();
      }

      if(m_timerManager.ShouldRunSync(m_lastSyncRun))
         RunSyncCycle();
   }
};

#endif
