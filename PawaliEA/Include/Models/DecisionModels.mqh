//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Decision sync models                        |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_MODELS_DECISION_MODELS_MQH
#define PAWALI_EA_MODELS_DECISION_MODELS_MQH

struct SPawaliDecisionRecord
{
   string   clientDecisionId;
   string   symbol;
   string   action;
   string   reason;
   datetime decidedAt;
   string   payloadJson;
   bool     synced;
};

#endif
