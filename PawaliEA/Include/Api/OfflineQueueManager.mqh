//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Offline queue manager                       |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_API_OFFLINE_QUEUE_MANAGER_MQH
#define PAWALI_EA_API_OFFLINE_QUEUE_MANAGER_MQH

#include "../Models/QueueModels.mqh"
#include "../Logs/Logger.mqh"
#include "../Utilities/FileUtils.mqh"
#include "../Utilities/StringUtils.mqh"
#include "../Utilities/TimeUtils.mqh"
#include "../Utilities/JsonSerializer.mqh"
#include "AuthenticationManager.mqh"

class CPawaliOfflineQueueManager
{
private:
   CPawaliAuthenticationManager *m_auth;
   CPawaliLogger                *m_logger;
   string                        m_queuePath;
   string                        m_dedupePath;
   string                        m_deadLetterPath;
   SPawaliQueueItem              m_items[];
   int                           m_maxAttempts;
   int                           m_maxItems;
   int                           m_replayCount;

   bool LoadQueue(void)
   {
      ArrayResize(m_items, 0);
      string content = "";
      if(!CPawaliFileUtils::ReadAllText(m_queuePath, content) || content == "")
         return true;

      string lines[];
      const int count = StringSplit(content, '\n', lines);
      for(int i = 0; i < count; i++)
      {
         if(lines[i] == "")
            continue;

         SPawaliQueueItem item;
         if(!CPawaliJsonSerializer::ParseQueueItem(lines[i], item))
            continue;

         const int index = ArraySize(m_items);
         ArrayResize(m_items, index + 1);
         m_items[index] = item;
      }
      return true;
   }

   bool SaveQueue(void) const
   {
      string content = "";
      for(int i = 0; i < ArraySize(m_items); i++)
         content += CPawaliJsonSerializer::SerializeQueueItem(m_items[i]) + "\n";
      return CPawaliFileUtils::WriteAllText(m_queuePath, content);
   }

   bool HasDedupeKey(const string key) const
   {
      if(key == "")
         return false;

      string content = "";
      if(!CPawaliFileUtils::ReadAllText(m_dedupePath, content))
         return false;
      return (StringFind(content, key + "\n") >= 0);
   }

   void RememberDedupeKey(const string key) const
   {
      if(key != "")
         CPawaliFileUtils::AppendLine(m_dedupePath, key);
   }

   void MoveToDeadLetter(const SPawaliQueueItem &item) const
   {
      const string line = CPawaliJsonSerializer::SerializeQueueItem(item);
      CPawaliFileUtils::AppendLine(m_deadLetterPath, line);
   }

public:
   CPawaliOfflineQueueManager(void) :
      m_auth(NULL),
      m_logger(NULL),
      m_maxAttempts(10),
      m_maxItems(1000),
      m_replayCount(0)
   {
      m_queuePath      = "PawaliEA/Queue/offline_queue.jsonl";
      m_dedupePath       = "PawaliEA/Queue/dedupe_keys.txt";
      m_deadLetterPath   = "PawaliEA/Queue/dead_letter.jsonl";
   }

   void Init(CPawaliAuthenticationManager *auth,
             CPawaliLogger *logger,
             const int maxAttempts,
             const int maxItems)
   {
      m_auth         = auth;
      m_logger       = logger;
      m_maxAttempts  = MathMax(1, maxAttempts);
      m_maxItems     = MathMax(10, maxItems);
      CPawaliFileUtils::EnsureDirectory("PawaliEA/Queue");
      LoadQueue();
   }

   int GetPendingCount(void) const
   {
      return ArraySize(m_items);
   }

   int GetReplayCount(void) const
   {
      return m_replayCount;
   }

   bool Enqueue(const ENUM_PAWALI_QUEUE_ITEM_TYPE type,
                const ENUM_PAWALI_HTTP_METHOD method,
                const string endpoint,
                const string payloadJson,
                const string idempotencyKey)
   {
      if(idempotencyKey != "" && HasDedupeKey(idempotencyKey))
         return true;

      if(ArraySize(m_items) >= m_maxItems)
      {
         if(m_logger != NULL)
            m_logger.ApiError("Offline queue capacity reached. Dropping newest request.");
         return false;
      }

      SPawaliQueueItem item;
      item.id             = CPawaliStringUtils::GenerateUuid();
      item.type           = type;
      item.method         = method;
      item.endpoint       = endpoint;
      item.payloadJson    = payloadJson;
      item.idempotencyKey = idempotencyKey;
      item.attempts       = 0;
      item.createdAt      = TimeCurrent();
      item.nextRetryAt    = TimeCurrent();

      const int index = ArraySize(m_items);
      ArrayResize(m_items, index + 1);
      m_items[index] = item;

      if(idempotencyKey != "")
         RememberDedupeKey(idempotencyKey);

      SaveQueue();
      if(m_logger != NULL)
         m_logger.ApiInfo(StringFormat("Queued offline request: %s [key=%s]",
                                         endpoint, idempotencyKey));
      return true;
   }

   bool Flush(void)
   {
      if(m_auth == NULL || ArraySize(m_items) == 0)
         return true;

      SPawaliQueueItem remaining[];
      ArrayResize(remaining, 0);

      for(int i = 0; i < ArraySize(m_items); i++)
      {
         if(TimeCurrent() < m_items[i].nextRetryAt)
         {
            const int idx = ArraySize(remaining);
            ArrayResize(remaining, idx + 1);
            remaining[idx] = m_items[i];
            continue;
         }

         SPawaliHttpResponse response;
         if(m_auth.ExecuteAuthorizedRequest(m_items[i].method,
                                            m_items[i].endpoint,
                                            m_items[i].payloadJson,
                                            m_items[i].idempotencyKey,
                                            response))
         {
            m_replayCount++;
            if(m_logger != NULL)
               m_logger.ApiInfo(StringFormat("Replayed queued request: %s", m_items[i].endpoint));
            continue;
         }

         m_items[i].attempts++;
         if(m_items[i].attempts >= m_maxAttempts)
         {
            MoveToDeadLetter(m_items[i]);
            if(m_logger != NULL)
               m_logger.ApiError(StringFormat("Queue item moved to dead letter: %s",
                                               m_items[i].endpoint));
            continue;
         }

         m_items[i].nextRetryAt = CPawaliTimeUtils::AddSeconds(TimeCurrent(),
                                                               30 * m_items[i].attempts);
         const int idx = ArraySize(remaining);
         ArrayResize(remaining, idx + 1);
         remaining[idx] = m_items[i];
      }

      ArrayResize(m_items, ArraySize(remaining));
      for(int i = 0; i < ArraySize(remaining); i++)
         m_items[i] = remaining[i];

      SaveQueue();
      return (ArraySize(m_items) == 0);
   }
};

#endif
