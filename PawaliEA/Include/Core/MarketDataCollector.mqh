//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Market data collector (read-only)           |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_CORE_MARKET_DATA_COLLECTOR_MQH
#define PAWALI_EA_CORE_MARKET_DATA_COLLECTOR_MQH

class CPawaliMarketDataCollector
{
private:
   string m_symbol;

public:
   void Init(const string symbol)
   {
      m_symbol = symbol;
   }

   double GetBid(void) const
   {
      return SymbolInfoDouble(m_symbol, SYMBOL_BID);
   }

   double GetAsk(void) const
   {
      return SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   }

   double GetSpreadPoints(void) const
   {
      return (double)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
   }

   datetime GetLastBarTime(const ENUM_TIMEFRAMES timeframe) const
   {
      return iTime(m_symbol, timeframe, 0);
   }
};

#endif
