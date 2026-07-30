//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Trade sync manager                          |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_CORE_TRADE_SYNC_MANAGER_MQH
#define PAWALI_EA_CORE_TRADE_SYNC_MANAGER_MQH

#include "../Interfaces/ISyncable.mqh"
#include "../Models/TradeModels.mqh"
#include "../Api/AuthenticationManager.mqh"
#include "../Api/OfflineQueueManager.mqh"
#include "../Enums/ApiEndpoints.mqh"
#include "../Utilities/JsonSerializer.mqh"
#include "../Logs/Logger.mqh"

class CPawaliTradeSyncManager : public IPawaliSyncable
{
private:
   CPawaliAuthenticationManager *m_auth;
   CPawaliOfflineQueueManager   *m_queue;
   CPawaliLogger                *m_logger;
   SPawaliTradeRecord            m_pending[];
   ENUM_PAWALI_SYNC_STATUS       m_status;
   datetime                      m_lastSyncAt;

   bool SendTrade(const SPawaliTradeRecord &trade)
   {
      const string payload = CPawaliJsonSerializer::SerializeTrade(trade);
      const string dedupe  = "trade-" + trade.clientTradeId;

      if(m_auth == NULL)
      {
         if(m_queue != NULL)
            m_queue.Enqueue(PAWALI_QUEUE_TRADE, PAWALI_HTTP_POST, PAWALI_API_TRADES, payload, dedupe);
         return false;
      }

      SPawaliHttpResponse response;
      if(!m_auth.ExecuteAuthorizedRequest(PAWALI_HTTP_POST, PAWALI_API_TRADES, payload,
                                           dedupe, response))
      {
         if(m_queue != NULL)
            m_queue.Enqueue(PAWALI_QUEUE_TRADE, PAWALI_HTTP_POST, PAWALI_API_TRADES, payload, dedupe);
         return false;
      }
      return true;
   }

public:
   CPawaliTradeSyncManager(void) :
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

   void QueueTrade(const SPawaliTradeRecord &trade)
   {
      const int index = ArraySize(m_pending);
      ArrayResize(m_pending, index + 1);
      m_pending[index] = trade;
      if(m_logger != NULL)
         m_logger.TradeInfo(StringFormat("Trade queued for sync: %s", trade.clientTradeId));
   }

   virtual bool Sync(void) override
   {
      m_status = PAWALI_SYNC_RUNNING;

      SPawaliTradeRecord remaining[];
      ArrayResize(remaining, 0);

      for(int i = 0; i < ArraySize(m_pending); i++)
      {
         if(SendTrade(m_pending[i]))
         {
            if(m_logger != NULL)
               m_logger.TradeInfo(StringFormat("Trade synced: %s", m_pending[i].clientTradeId));
            continue;
         }

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
