//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Command handler interface                   |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_INTERFACES_I_COMMAND_HANDLER_MQH
#define PAWALI_EA_INTERFACES_I_COMMAND_HANDLER_MQH

#include "../Models/CommandModels.mqh"

class IPawaliCommandHandler
{
public:
   virtual bool Execute(const SPawaliRemoteCommand &command,
                        SPawaliCommandResult &result) = 0;
};

#endif
