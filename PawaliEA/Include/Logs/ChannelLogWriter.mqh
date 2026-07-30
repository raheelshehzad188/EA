//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Channel log writer                          |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_LOGS_CHANNEL_LOG_WRITER_MQH
#define PAWALI_EA_LOGS_CHANNEL_LOG_WRITER_MQH

#include "../Interfaces/ILogWriter.mqh"
#include "../Utilities/FileUtils.mqh"
#include "../Utilities/TimeUtils.mqh"

class CPawaliChannelLogWriter : public IPawaliLogWriter
{
private:
   string m_logRoot;
   long   m_maxFileBytes;

   string BuildPath(const ENUM_PAWALI_LOG_CHANNEL channel) const
   {
      return m_logRoot + "/" + PawaliLogChannelFileName(channel);
   }

   void RotateIfNeeded(const ENUM_PAWALI_LOG_CHANNEL channel) const
   {
      CPawaliFileUtils::RotateIfNeeded(BuildPath(channel), m_maxFileBytes);
   }

public:
   CPawaliChannelLogWriter(void) :
      m_logRoot("PawaliEA/Logs"),
      m_maxFileBytes(5242880)
   {}

   void SetLogRoot(const string logRoot)
   {
      m_logRoot = logRoot;
      CPawaliFileUtils::EnsureDirectory(m_logRoot);
   }

   void SetMaxFileBytes(const long maxBytes)
   {
      m_maxFileBytes = MathMax(1048576, maxBytes);
   }

   virtual void Write(const ENUM_PAWALI_LOG_CHANNEL channel,
                      const string level,
                      const string message) const override
   {
      RotateIfNeeded(channel);

      const string line = StringFormat("[%s] [%s] %s",
                                       CPawaliTimeUtils::ToIso8601(TimeCurrent()),
                                       level,
                                       message);
      CPawaliFileUtils::AppendLine(BuildPath(channel), line);
   }
};

#endif
