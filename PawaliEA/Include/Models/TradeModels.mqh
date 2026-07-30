//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Trade sync models                           |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_MODELS_TRADE_MODELS_MQH
#define PAWALI_EA_MODELS_TRADE_MODELS_MQH

struct SPawaliTradeRecord
{
   string   clientTradeId;
   string   ticket;
   string   symbol;
   string   direction;
   double   volume;
   double   entryPrice;
   double   exitPrice;
   double   stopLoss;
   double   takeProfit;
   double   profit;
   datetime openedAt;
   datetime closedAt;
   string   comment;
   bool     synced;
};

#endif
