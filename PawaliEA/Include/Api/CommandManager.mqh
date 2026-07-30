//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Remote command manager                      |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_API_COMMAND_MANAGER_MQH
#define PAWALI_EA_API_COMMAND_MANAGER_MQH

#include "../Interfaces/ICommandHandler.mqh"
#include "../Models/CommandModels.mqh"
#include "../Models/OperationResult.mqh"
#include "AuthenticationManager.mqh"
#include "OfflineQueueManager.mqh"
#include "../Enums/ApiEndpoints.mqh"
#include "../Utilities/JsonSerializer.mqh"
#include "../Utilities/FileUtils.mqh"
#include "../Logs/Logger.mqh"

class CPawaliCommandManager : public IPawaliCommandHandler
{
public:
   struct SCommandContext
   {
      bool   tradingPaused;
      bool   buyEnabled;
      bool   sellEnabled;
      bool   forceSettingsSync;
      bool   restartRequested;
      double riskPercent;
   };

private:
   CPawaliAuthenticationManager *m_auth;
   CPawaliOfflineQueueManager   *m_queue;
   CPawaliLogger                *m_logger;
   SCommandContext               m_context;
   string                        m_processedPath;
   string                        m_processedCache;
   int                           m_pollCount;
   int                           m_executedCount;

   bool WasProcessed(const string uuid) const
   {
      if(uuid == "")
         return true;
      return (StringFind(m_processedCache, uuid + "\n") >= 0);
   }

   void MarkProcessed(const string uuid)
   {
      if(uuid == "" || WasProcessed(uuid))
         return;

      m_processedCache += uuid + "\n";
      CPawaliFileUtils::AppendLine(m_processedPath, uuid);
   }

   bool LoadProcessedCache(void)
   {
      m_processedCache = "";
      return CPawaliFileUtils::ReadAllText(m_processedPath, m_processedCache);
   }

   bool CompleteCommand(const string uuid, const SPawaliCommandResult &result)
   {
      if(m_auth == NULL)
         return false;

      const string endpoint = StringFormat(PAWALI_API_COMMAND_COMPLETE, uuid);
      const string payload  = CPawaliJsonSerializer::SerializeCommandComplete(result);
      const string dedupe   = "command-complete-" + uuid;

      SPawaliHttpResponse response;
      if(!m_auth.ExecuteAuthorizedRequest(PAWALI_HTTP_POST, endpoint, payload,
                                           dedupe, response))
      {
         if(m_queue != NULL)
            m_queue.Enqueue(PAWALI_QUEUE_COMMAND, PAWALI_HTTP_POST, endpoint, payload, dedupe);
         return false;
      }
      return true;
   }

public:
   CPawaliCommandManager(void) :
      m_auth(NULL),
      m_queue(NULL),
      m_logger(NULL),
      m_pollCount(0),
      m_executedCount(0)
   {
      m_context.tradingPaused     = false;
      m_context.buyEnabled        = true;
      m_context.sellEnabled       = true;
      m_context.forceSettingsSync = false;
      m_context.restartRequested  = false;
      m_context.riskPercent       = 1.0;
      m_processedPath             = "PawaliEA/Cache/processed_commands.txt";
   }

   void Init(CPawaliAuthenticationManager *auth,
             CPawaliOfflineQueueManager *queue,
             CPawaliLogger *logger)
   {
      m_auth   = auth;
      m_queue  = queue;
      m_logger = logger;
      CPawaliFileUtils::EnsureDirectory("PawaliEA/Cache");
      LoadProcessedCache();
   }

   SCommandContext GetContext(void) const
   {
      return m_context;
   }

   int GetPollCount(void) const { return m_pollCount; }
   int GetExecutedCount(void) const { return m_executedCount; }

   void ClearTransientFlags(void)
   {
      m_context.forceSettingsSync = false;
      m_context.restartRequested  = false;
   }

   ENUM_PAWALI_OPERATION_RESULT PollCommands(void)
   {
      if(m_auth == NULL)
         return PAWALI_OP_FAILED;

      m_pollCount++;

      SPawaliHttpResponse response;
      if(!m_auth.ExecuteAuthorizedRequest(PAWALI_HTTP_GET, PAWALI_API_COMMANDS, "",
                                           "commands-poll", response))
      {
         if(m_logger != NULL)
            m_logger.ApiWarn(StringFormat("Command poll failed: %s", response.errorMessage));
         return PAWALI_OP_FAILED;
      }

      SPawaliRemoteCommand commands[];
      CPawaliJsonSerializer::ParseCommandArray(response.body, commands);

      for(int i = 0; i < ArraySize(commands); i++)
      {
         if(WasProcessed(commands[i].uuid))
            continue;

         SPawaliCommandResult result;
         Execute(commands[i], result);
         CompleteCommand(commands[i].uuid, result);
         MarkProcessed(commands[i].uuid);
         m_executedCount++;
      }

      return PAWALI_OP_SUCCEEDED;
   }

   virtual bool Execute(const SPawaliRemoteCommand &command,
                        SPawaliCommandResult &result) override
   {
      result.uuid     = command.uuid;
      result.success  = true;
      result.message  = "OK";

      switch(command.type)
      {
         case PAWALI_CMD_PAUSE_TRADING:
            m_context.tradingPaused = true;
            result.message = "Trading paused";
            break;
         case PAWALI_CMD_RESUME_TRADING:
            m_context.tradingPaused = false;
            result.message = "Trading resumed";
            break;
         case PAWALI_CMD_UPDATE_SETTINGS:
         case PAWALI_CMD_FORCE_SYNC:
            m_context.forceSettingsSync = true;
            result.message = "Settings sync requested";
            break;
         case PAWALI_CMD_RESTART_EA:
            m_context.restartRequested = true;
            result.message = "Restart requested";
            break;
         case PAWALI_CMD_CLOSE_ALL:
         case PAWALI_CMD_CLOSE_BUY:
         case PAWALI_CMD_CLOSE_SELL:
            result.message = "Close command acknowledged (trading engine placeholder)";
            break;
         case PAWALI_CMD_DISABLE_BUY:
            m_context.buyEnabled = false;
            result.message = "Buy disabled";
            break;
         case PAWALI_CMD_DISABLE_SELL:
            m_context.sellEnabled = false;
            result.message = "Sell disabled";
            break;
         case PAWALI_CMD_REDUCE_RISK:
            m_context.riskPercent = MathMax(0.1, m_context.riskPercent * 0.5);
            result.message = StringFormat("Risk reduced to %.2f%%", m_context.riskPercent);
            break;
         default:
            result.success = false;
            result.message = "Unknown command";
            break;
      }

      if(m_logger != NULL)
         m_logger.ExpertInfo(StringFormat("Command %s [%s] -> %s",
                                            PawaliCommandToString(command.type),
                                            command.uuid,
                                            result.message));
      return result.success;
   }
};

#endif
