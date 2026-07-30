//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Trade repository placeholder                |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_TRADING_TRADE_REPOSITORY_MQH
#define PAWALI_EA_TRADING_TRADE_REPOSITORY_MQH

#include "../Models/TradeModels.mqh"

class CPawaliTradeRepository
{
private:
   SPawaliTradeRecord m_records[];

public:
   void Add(const SPawaliTradeRecord &record)
   {
      const int index = ArraySize(m_records);
      ArrayResize(m_records, index + 1);
      m_records[index] = record;
   }

   int Count(void) const
   {
      return ArraySize(m_records);
   }

   bool GetAt(const int index, SPawaliTradeRecord &record) const
   {
      if(index < 0 || index >= ArraySize(m_records))
         return false;
      record = m_records[index];
      return true;
   }
};

#endif
