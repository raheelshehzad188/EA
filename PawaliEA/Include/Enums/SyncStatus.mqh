//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Sync and queue status                       |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_ENUMS_SYNC_STATUS_MQH
#define PAWALI_EA_ENUMS_SYNC_STATUS_MQH

enum ENUM_PAWALI_SYNC_STATUS
{
   PAWALI_SYNC_IDLE      = 0,
   PAWALI_SYNC_RUNNING   = 1,
   PAWALI_SYNC_SUCCEEDED = 2,
   PAWALI_SYNC_FAILED    = 3,
   PAWALI_SYNC_QUEUED    = 4
};

enum ENUM_PAWALI_QUEUE_ITEM_TYPE
{
   PAWALI_QUEUE_HEARTBEAT = 0,
   PAWALI_QUEUE_TRADE     = 1,
   PAWALI_QUEUE_DECISION  = 2,
   PAWALI_QUEUE_COMMAND   = 3
};

enum ENUM_PAWALI_HTTP_METHOD
{
   PAWALI_HTTP_GET  = 0,
   PAWALI_HTTP_POST = 1
};

#endif
