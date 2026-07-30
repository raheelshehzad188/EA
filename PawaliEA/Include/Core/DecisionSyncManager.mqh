//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Decision sync manager                       |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_CORE_DECISION_SYNC_MANAGER_MQH
#define PAWALI_EA_CORE_DECISION_SYNC_MANAGER_MQH

#include "../Interfaces/ISyncable.mqh"
#include "../Models/DecisionModels.mqh"
#include "../Api/AuthenticationManager.mqh"
#include "../Api/OfflineQueueManager.mqh"
#include "../Enums/ApiEndpoints.mqh"
#include "../Utilities/JsonSerializer.mqh"
#include "../Logs/Logger.mqh"

class CPawaliDecisionSyncManager : public IPawaliSyncable
{
private:
   CPawaliAuthenticationManager *m_auth;
   CPawaliOfflineQueueManager   *m_queue;
   CPawaliLogger                *m_logger;
   SPawaliDecisionRecord         m_pending[];
   ENUM_PAWALI_SYNC_STATUS       m_status;
   datetime                      m_lastSyncAt;

   bool SendDecision(const SPawaliDecisionRecord &decision)
   {
      const string payload = CPawaliJsonSerializer::SerializeDecision(decision);
      const string dedupe  = "decision-" + decision.clientDecisionId;

      if(m_auth == NULL)
      {
         if(m_queue != NULL)
            m_queue.Enqueue(PAWALI_QUEUE_DECISION, PAWALI_HTTP_POST, PAWALI_API_DECISIONS, payload, dedupe);
         return false;
      }

      SPawaliHttpResponse response;
      if(!m_auth.ExecuteAuthorizedRequest(PAWALI_HTTP_POST, PAWALI_API_DECISIONS, payload,
                                           dedupe, response))
      {
         if(m_queue != NULL)
            m_queue.Enqueue(PAWALI_QUEUE_DECISION, PAWALI_HTTP_POST, PAWALI_API_DECISIONS, payload, dedupe);
         return false;
      }
      return true;
   }

public:
   CPawaliDecisionSyncManager(void) :
      m_auth(NULL), m_queue(NULL), m_logger(NULL),
      m_status(PAWALI_SYNC_IDLE), m_lastSyncAt(0)
   {}

   void Init(CPawaliAuthenticationManager *auth,
             CPawaliOfflineQueueManager *queue,
             CPawaliLogger *logger)
   {
      m_auth   = auth;
      m_queue  = queue;
      m_logger = logger;
   }

   void QueueDecision(const SPawaliDecisionRecord &decision)
   {
      const int index = ArraySize(m_pending);
      ArrayResize(m_pending, index + 1);
      m_pending[index] = decision;
   }

   virtual bool Sync(void) override
   {
      m_status = PAWALI_SYNC_RUNNING;

      SPawaliDecisionRecord remaining[];
      ArrayResize(remaining, 0);

      for(int i = 0; i < ArraySize(m_pending); i++)
      {
         if(SendDecision(m_pending[i]))
            continue;

         const int idx = ArraySize(remaining);
         ArrayResize(remaining, idx + 1);
         remaining[idx] = m_pending[i];
      }

      ArrayResize(m_pending, ArraySize(remaining));
      for(int i = 0; i < ArraySize(remaining); i++)
         m_pending[i] = remaining[i];

      m_lastSyncAt = TimeCurrent();
      m_status = (ArraySize(m_pending) == 0 ? PAWALI_SYNC_SUCCEEDED : PAWALI_SYNC_FAILED);
      return (m_status == PAWALI_SYNC_SUCCEEDED);
   }

   virtual ENUM_PAWALI_SYNC_STATUS GetStatus(void) const override
   {
      return m_status;
   }

   virtual datetime GetLastSyncTime(void) const override
   {
      return m_lastSyncAt;
   }
};

#endif
