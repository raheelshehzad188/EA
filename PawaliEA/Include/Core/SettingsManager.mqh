//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Settings manager                            |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_CORE_SETTINGS_MANAGER_MQH
#define PAWALI_EA_CORE_SETTINGS_MANAGER_MQH

#include "../Models/SettingsModels.mqh"
#include "../Models/OperationResult.mqh"
#include "../Api/AuthenticationManager.mqh"
#include "../Enums/ApiEndpoints.mqh"
#include "../Utilities/JsonSerializer.mqh"
#include "../Utilities/FileUtils.mqh"
#include "../Logs/Logger.mqh"

class CPawaliSettingsManager
{
private:
   CPawaliAuthenticationManager *m_auth;
   CPawaliLogger                *m_logger;
   SPawaliRemoteSettings         m_settings;
   string                        m_cachePath;
   datetime                      m_lastDownloadAt;
   string                        m_lastError;
   int                           m_downloadCount;

   bool SaveCache(void) const
   {
      const string json = StringFormat(
         "{\"version\":%d,\"trading_enabled\":%s,\"buy_enabled\":%s,\"sell_enabled\":%s,"
         "\"risk_percent\":%.4f,\"max_spread_points\":%d,\"strategy_version\":\"%s\",\"updated_at\":%I64d}",
         m_settings.version,
         (m_settings.tradingEnabled ? "true" : "false"),
         (m_settings.buyEnabled ? "true" : "false"),
         (m_settings.sellEnabled ? "true" : "false"),
         m_settings.riskPercent,
         m_settings.maxSpreadPoints,
         m_settings.strategyVersion,
         (long)m_settings.updatedAt);
      return CPawaliFileUtils::WriteAllText(m_cachePath, json);
   }

   bool LoadCache(void)
   {
      string json = "";
      if(!CPawaliFileUtils::ReadAllText(m_cachePath, json))
         return false;

      if(!CPawaliJsonSerializer::ParseSettings(json, m_settings))
         return false;

      if(m_logger != NULL)
         m_logger.ExpertInfo(StringFormat("Loaded cached settings v%d", m_settings.version));
      return true;
   }

public:
   CPawaliSettingsManager(void) :
      m_auth(NULL),
      m_logger(NULL),
      m_lastDownloadAt(0),
      m_downloadCount(0)
   {
      m_cachePath = "PawaliEA/Cache/settings.json";
      m_lastError = "";
      m_settings.isLoaded = false;
   }

   void Init(CPawaliAuthenticationManager *auth, CPawaliLogger *logger)
   {
      m_auth   = auth;
      m_logger = logger;
      CPawaliFileUtils::EnsureDirectory("PawaliEA/Cache");
      LoadCache();
   }

   SPawaliRemoteSettings GetSettingsCopy(void) const
   {
      return m_settings;
   }

   int GetVersion(void) const
   {
      return m_settings.version;
   }

   datetime GetLastDownloadAt(void) const
   {
      return m_lastDownloadAt;
   }

   string GetLastError(void) const
   {
      return m_lastError;
   }

   int GetDownloadCount(void) const
   {
      return m_downloadCount;
   }

   ENUM_PAWALI_OPERATION_RESULT DownloadSettings(const bool force)
   {
      m_lastError = "";

      if(m_auth == NULL)
      {
         m_lastError = "Authentication manager unavailable.";
         return (LoadCache() ? PAWALI_OP_SUCCEEDED : PAWALI_OP_FAILED);
      }

      SPawaliHttpResponse response;
      if(!m_auth.ExecuteAuthorizedRequest(PAWALI_HTTP_GET, PAWALI_API_SETTINGS, "",
                                           "settings-download", response))
      {
         m_lastError = response.errorMessage;
         if(m_logger != NULL)
            m_logger.ApiWarn(StringFormat("Settings download failed: %s", m_lastError));

         if(LoadCache())
            return PAWALI_OP_OFFLINE_QUEUED;
         return PAWALI_OP_FAILED;
      }

      SPawaliRemoteSettings incoming;
      if(!CPawaliJsonSerializer::ParseSettings(response.body, incoming))
      {
         m_lastError = "Settings payload parse failed.";
         if(m_logger != NULL)
            m_logger.ApiError(m_lastError);
         return PAWALI_OP_FAILED;
      }

      if(!force && m_settings.isLoaded && incoming.version == m_settings.version)
      {
         m_lastDownloadAt = TimeCurrent();
         return PAWALI_OP_NO_CHANGES;
      }

      const int previousVersion = m_settings.version;
      m_settings       = incoming;
      m_lastDownloadAt = TimeCurrent();
      m_downloadCount++;
      SaveCache();

      if(m_logger != NULL)
      {
         m_logger.ExpertInfo(StringFormat("Settings reloaded v%d -> v%d Strategy=%s",
                                            previousVersion,
                                            m_settings.version,
                                            m_settings.strategyVersion));
      }
      return PAWALI_OP_SUCCEEDED;
   }
};

#endif
