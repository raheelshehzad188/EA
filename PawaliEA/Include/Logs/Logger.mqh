//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Central logger                              |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_LOGS_LOGGER_MQH
#define PAWALI_EA_LOGS_LOGGER_MQH

#include "ChannelLogWriter.mqh"

enum ENUM_PAWALI_LOG_LEVEL
{
   PAWALI_LOG_LEVEL_ERROR = 0,
   PAWALI_LOG_LEVEL_WARN  = 1,
   PAWALI_LOG_LEVEL_INFO  = 2,
   PAWALI_LOG_LEVEL_DEBUG = 3
};

class CPawaliLogger
{
private:
   CPawaliChannelLogWriter m_writer;
   ENUM_PAWALI_LOG_LEVEL   m_minLevel;

   bool ShouldLog(const ENUM_PAWALI_LOG_LEVEL level) const
   {
      return (level <= m_minLevel);
   }

   void WriteAll(const ENUM_PAWALI_LOG_CHANNEL channel,
                 const string level,
                 const ENUM_PAWALI_LOG_LEVEL minLevel,
                 const string message) const
   {
      if(!ShouldLog(minLevel))
         return;

      m_writer.Write(channel, level, message);
      Print("[PawaliEA] ", level, " ", message);
   }

public:
   CPawaliLogger(void) : m_minLevel(PAWALI_LOG_LEVEL_INFO) {}

   void Init(const string logRoot, const ENUM_PAWALI_LOG_LEVEL minLevel = PAWALI_LOG_LEVEL_INFO)
   {
      m_minLevel = minLevel;
      m_writer.SetLogRoot(logRoot);
   }

   void SetMinLevel(const ENUM_PAWALI_LOG_LEVEL minLevel)
   {
      m_minLevel = minLevel;
   }

   void ExpertInfo(const string message) const
   {
      WriteAll(PAWALI_LOG_EXPERT, "INFO", PAWALI_LOG_LEVEL_INFO, message);
   }

   void ExpertDebug(const string message) const
   {
      WriteAll(PAWALI_LOG_EXPERT, "DEBUG", PAWALI_LOG_LEVEL_DEBUG, message);
   }

   void ExpertWarn(const string message) const
   {
      WriteAll(PAWALI_LOG_EXPERT, "WARN", PAWALI_LOG_LEVEL_WARN, message);
   }

   void ApiInfo(const string message) const
   {
      WriteAll(PAWALI_LOG_API, "INFO", PAWALI_LOG_LEVEL_INFO, message);
   }

   void ApiWarn(const string message) const
   {
      WriteAll(PAWALI_LOG_API, "WARN", PAWALI_LOG_LEVEL_WARN, message);
   }

   void ApiError(const string message) const
   {
      WriteAll(PAWALI_LOG_API, "ERROR", PAWALI_LOG_LEVEL_ERROR, message);
   }

   void TradeInfo(const string message) const
   {
      WriteAll(PAWALI_LOG_TRADE, "INFO", PAWALI_LOG_LEVEL_INFO, message);
   }

   void Error(const string message) const
   {
      WriteAll(PAWALI_LOG_ERROR, "ERROR", PAWALI_LOG_LEVEL_ERROR, message);
   }

   void Performance(const string message) const
   {
      WriteAll(PAWALI_LOG_PERFORMANCE, "INFO", PAWALI_LOG_LEVEL_INFO, message);
   }

   IPawaliLogWriter* GetWriter(void)
   {
      return GetPointer(m_writer);
   }
};

#endif
