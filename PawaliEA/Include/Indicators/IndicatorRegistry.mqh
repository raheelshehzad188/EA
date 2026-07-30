//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Indicator module placeholder                |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_INDICATORS_INDICATOR_REGISTRY_MQH
#define PAWALI_EA_INDICATORS_INDICATOR_REGISTRY_MQH

class CPawaliIndicatorRegistry
{
public:
   bool Init(const string symbol, const ENUM_TIMEFRAMES timeframe)
   {
      m_symbol    = symbol;
      m_timeframe = timeframe;
      return true;
   }

private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
};

#endif
