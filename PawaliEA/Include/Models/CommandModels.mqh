//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Remote command models                       |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_MODELS_COMMAND_MODELS_MQH
#define PAWALI_EA_MODELS_COMMAND_MODELS_MQH

#include "../Enums/CommandTypes.mqh"

struct SPawaliRemoteCommand
{
   string               uuid;
   ENUM_PAWALI_COMMAND  type;
   string               payloadJson;
   datetime             receivedAt;
   bool                 completed;
};

struct SPawaliCommandResult
{
   bool   success;
   string message;
   string uuid;
};

#endif
