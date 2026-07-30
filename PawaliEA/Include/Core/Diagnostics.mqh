//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Diagnostics aggregator                      |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_CORE_DIAGNOSTICS_MQH
#define PAWALI_EA_CORE_DIAGNOSTICS_MQH

#include "../Enums/ConnectionStatus.mqh"
#include "../Enums/SyncStatus.mqh"
#include "../Models/LicenseModels.mqh"
#include "../Logs/Logger.mqh"

struct SPawaliDiagnosticsSnapshot
{
   ENUM_PAWALI_CONNECTION_STATUS connectionStatus;
   ENUM_PAWALI_LICENSE_STATUS    licenseStatus;
   ENUM_PAWALI_API_STATUS        apiStatus;
   ENUM_PAWALI_SYNC_STATUS       tradeSyncStatus;
   ENUM_PAWALI_SYNC_STATUS       decisionSyncStatus;
   string                        strategyVersion;
   datetime                      lastHeartbeatAt;
   datetime                      lastSettingsDownloadAt;
   datetime                      lastTradeSyncAt;
   datetime                      lastDecisionSyncAt;
   int                           pendingQueueCount;
   int                           queueReplayCount;
   int                           apiFailureStreak;
   int                           heartbeatFailures;
   int                           authRefreshCount;
   int                           commandPollCount;
   int                           settingsDownloadCount;
   bool                          tradingPaused;
   string                        lastError;
};

class CPawaliDiagnostics
{
private:
   CPawaliLogger *m_logger;
   string         m_lastError;
   datetime       m_lastLogAt;
   int            m_logIntervalSec;

public:
   CPawaliDiagnostics(void) :
      m_logger(NULL),
      m_lastError(""),
      m_lastLogAt(0),
      m_logIntervalSec(60)
   {}

   void Init(CPawaliLogger *logger, const int logIntervalSec = 60)
   {
      m_logger         = logger;
      m_logIntervalSec = MathMax(10, logIntervalSec);
   }

   void SetLastError(const string errorMessage)
   {
      m_lastError = errorMessage;
   }

   void LogSnapshot(SPawaliDiagnosticsSnapshot &snapshot)
   {
      if(m_logger == NULL)
         return;

      if(m_lastLogAt > 0 &&
         (TimeCurrent() - m_lastLogAt) < m_logIntervalSec &&
         snapshot.connectionStatus == PAWALI_CONN_ONLINE)
         return;

      m_lastLogAt = TimeCurrent();

      m_logger.Performance(StringFormat(
         "Diagnostics | Conn=%s License=%s API=%d Strategy=%s Queue=%d Replay=%d "
         "HBFail=%d AuthRefresh=%d CmdPoll=%d SettingsDL=%d LastError=%s",
         PawaliConnectionStatusLabel(snapshot.connectionStatus),
         PawaliLicenseStatusLabel(snapshot.licenseStatus),
         (int)snapshot.apiStatus,
         snapshot.strategyVersion,
         snapshot.pendingQueueCount,
         snapshot.queueReplayCount,
         snapshot.heartbeatFailures,
         snapshot.authRefreshCount,
         snapshot.commandPollCount,
         snapshot.settingsDownloadCount,
         (snapshot.lastError != "" ? snapshot.lastError : "none")));
   }

   void LogHealthAlert(const SPawaliDiagnosticsSnapshot &snapshot) const
   {
      if(m_logger == NULL)
         return;

      if(snapshot.connectionStatus == PAWALI_CONN_OFFLINE ||
         snapshot.apiFailureStreak >= 3 ||
         snapshot.heartbeatFailures >= 3)
      {
         m_logger.ExpertWarn(StringFormat(
            "Health alert | Conn=%s APIStreak=%d HeartbeatFailures=%d Queue=%d",
            PawaliConnectionStatusLabel(snapshot.connectionStatus),
            snapshot.apiFailureStreak,
            snapshot.heartbeatFailures,
            snapshot.pendingQueueCount));
      }
   }
};

#endif
