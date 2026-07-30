//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Log writer interface                        |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_INTERFACES_I_LOG_WRITER_MQH
#define PAWALI_EA_INTERFACES_I_LOG_WRITER_MQH

#include "../Enums/LogChannel.mqh"

class IPawaliLogWriter
{
public:
   virtual void Write(const ENUM_PAWALI_LOG_CHANNEL channel,
                      const string level,
                      const string message) const = 0;
};

#endif
