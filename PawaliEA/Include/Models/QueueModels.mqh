//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Offline queue models                        |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_MODELS_QUEUE_MODELS_MQH
#define PAWALI_EA_MODELS_QUEUE_MODELS_MQH

#include "../Enums/SyncStatus.mqh"

struct SPawaliQueueItem
{
   string                   id;
   ENUM_PAWALI_QUEUE_ITEM_TYPE type;
   ENUM_PAWALI_HTTP_METHOD  method;
   string                   endpoint;
   string                   payloadJson;
   string                   idempotencyKey;
   int                      attempts;
   datetime                 createdAt;
   datetime                 nextRetryAt;
};

#endif
