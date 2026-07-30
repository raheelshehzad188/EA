//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Sync interface                              |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_INTERFACES_I_SYNCABLE_MQH
#define PAWALI_EA_INTERFACES_I_SYNCABLE_MQH

#include "../Enums/SyncStatus.mqh"

class IPawaliSyncable
{
public:
   virtual bool Sync(void) = 0;
   virtual ENUM_PAWALI_SYNC_STATUS GetStatus(void) const = 0;
   virtual datetime GetLastSyncTime(void) const = 0;
};

#endif
