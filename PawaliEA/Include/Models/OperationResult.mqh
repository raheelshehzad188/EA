//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Foundation operation results                |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_MODELS_OPERATION_RESULT_MQH
#define PAWALI_EA_MODELS_OPERATION_RESULT_MQH

enum ENUM_PAWALI_OPERATION_RESULT
{
   PAWALI_OP_SUCCEEDED      = 0,
   PAWALI_OP_FAILED         = 1,
   PAWALI_OP_OFFLINE_QUEUED = 2,
   PAWALI_OP_UNAUTHORIZED   = 3,
   PAWALI_OP_NO_CHANGES     = 4
};

#endif
