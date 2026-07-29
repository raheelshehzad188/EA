//+------------------------------------------------------------------+
//|                                                         v1.mq5   |
//|                        Professional Trend-Following Expert Advisor|
//+------------------------------------------------------------------+
#property copyright "Professional EA"
#property version   "2.00"

#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/AccountInfo.mqh>

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+
enum ENUM_LOT_MODE
{
   LOT_MODE_FIXED       = 0,   // Fixed lot size
   LOT_MODE_RISK_PERCENT = 1   // Risk percent of balance
};

enum ENUM_LOG_LEVEL
{
   LOG_LEVEL_ERROR = 0,
   LOG_LEVEL_INFO  = 1,
   LOG_LEVEL_DEBUG = 2
};

enum ENUM_SIGNAL
{
   SIGNAL_NONE = 0,
   SIGNAL_BUY  = 1,
   SIGNAL_SELL = -1
};

enum ENUM_SETUP_STATE
{
   SETUP_NONE       = 0,
   SETUP_ARMED_BUY  = 1,
   SETUP_ARMED_SELL = -1
};

//+------------------------------------------------------------------+
//| Resolve broker-supported order filling mode                       |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetFillingMode(const string symbol)
{
   const long filling = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);

   if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return ORDER_FILLING_FOK;
   if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return ORDER_FILLING_IOC;

   return ORDER_FILLING_RETURN;
}

//+------------------------------------------------------------------+
//| Input parameters (optimization-friendly)                          |
//+------------------------------------------------------------------+
input group "=== General ==="
input ulong          InpMagicNumber        = 20260729;     // Magic number
input string         InpTradeComment       = "ProEA_v1";   // Trade comment

input group "=== Trend Filter (EMA) ==="
input int            InpFastEMA            = 50;           // Fast EMA period
input int            InpSlowEMA            = 200;          // Slow EMA period

input group "=== RSI Momentum Cross ==="
input int            InpRSIPeriod          = 14;           // RSI period
input double         InpRSICrossLevel      = 50.0;         // RSI cross trigger level

input group "=== Higher Timeframe Trend (H4) ==="
input ENUM_TIMEFRAMES InpHTFTimeframe      = PERIOD_H4;    // HTF for trend confirmation
input int            InpHTFFastEMA         = 50;           // HTF fast EMA period
input int            InpHTFSlowEMA         = 200;          // HTF slow EMA period

input group "=== Market Structure (BOS) ==="
input int            InpSwingLookback      = 50;           // Bars to scan for swings
input int            InpSwingStrength      = 2;            // Swing pivot strength (bars each side)

input group "=== Pullback Entry ==="
input int            InpPullbackMaxBars    = 8;            // Max bars to wait for pullback
input double         InpPullbackATRZone    = 0.5;          // Pullback zone (ATR from EMA)

input group "=== ATR Volatility Filter ==="
input int            InpATRAvgPeriod       = 20;           // ATR average period
input double         InpATRMinRatio        = 0.85;         // Min ATR vs average (avoid dead markets)
input double         InpATRMaxRatio        = 2.50;         // Max ATR vs average (avoid news spikes)

input group "=== Dynamic ADX ==="
input bool           InpUseDynamicADX      = true;         // Enable dynamic ADX threshold
input int            InpADXAvgPeriod       = 14;           // ADX average period
input bool           InpRequireADXRising   = true;         // Require ADX rising on closed bar

input group "=== Range Avoidance ==="
input double         InpMinEMASeparationATR = 0.35;        // Min |EMA50-EMA200| / ATR

input group "=== Candle Confirmation ==="
input bool           InpUseCandleConfirm   = true;         // Require candle confirmation

input group "=== Exit Logic ==="
input bool           InpUseStructureExit   = true;         // Close on structure invalidation
input bool           InpUseRSIExit         = true;         // Close on RSI momentum reversal
input bool           InpUseOppositeBOSExit = true;         // Close on opposite BOS

input group "=== Legacy ADX (base threshold) ==="
input int            InpADXPeriod          = 14;           // ADX period
input double         InpADXMinLevel        = 22.0;         // Base minimum ADX level

input group "=== ATR Stop Loss / Take Profit ==="
input int            InpATRPeriod          = 14;           // ATR period
input double         InpSL_ATR_Multiplier  = 2.0;          // Stop Loss (ATR multiplier)
input double         InpTP_ATR_Multiplier  = 3.0;          // Take Profit (ATR multiplier)

input group "=== Money Management ==="
input ENUM_LOT_MODE  InpLotMode            = LOT_MODE_RISK_PERCENT; // Lot sizing mode
input double         InpFixedLot           = 0.10;         // Fixed lot size
input double         InpRiskPercent        = 1.0;          // Risk percent per trade

input group "=== Spread Filter ==="
input int            InpMaxSpreadPoints    = 30;           // Maximum spread (points)

input group "=== Trading Session ==="
input bool           InpUseSessionFilter   = true;         // Enable session filter
input int            InpSessionStartHour   = 8;            // Session start hour (server)
input int            InpSessionStartMinute = 0;            // Session start minute
input int            InpSessionEndHour   = 20;           // Session end hour (server)
input int            InpSessionEndMinute = 0;            // Session end minute

input group "=== Trailing Stop ==="
input bool           InpUseTrailingStop    = true;         // Enable trailing stop
input double         InpTrailStartATR      = 1.5;          // Trailing start (ATR multiplier)
input double         InpTrailStepATR       = 0.5;          // Trailing step (ATR multiplier)

input group "=== Break-Even ==="
input bool           InpUseBreakEven       = true;         // Enable break-even
input double         InpBreakEvenTriggerATR = 1.0;         // Break-even trigger (ATR multiplier)
input int            InpBreakEvenOffsetPoints = 5;         // Break-even offset (points)

input group "=== Logging ==="
input ENUM_LOG_LEVEL InpLogLevel           = LOG_LEVEL_INFO; // Log verbosity

//+------------------------------------------------------------------+
//| CLogger - Centralized logging                                     |
//+------------------------------------------------------------------+
class CLogger
{
private:
   ENUM_LOG_LEVEL m_level;
   string         m_prefix;

public:
   CLogger(void) : m_level(LOG_LEVEL_INFO), m_prefix("ProEA") {}

   void Init(const ENUM_LOG_LEVEL level, const string prefix)
   {
      m_level  = level;
      m_prefix = prefix;
   }

   void Error(const string message) const
   {
      Print(m_prefix, " [ERROR] ", message);
   }

   void Info(const string message) const
   {
      if(m_level >= LOG_LEVEL_INFO)
         Print(m_prefix, " [INFO]  ", message);
   }

   void Debug(const string message) const
   {
      if(m_level >= LOG_LEVEL_DEBUG)
         Print(m_prefix, " [DEBUG] ", message);
   }
};

//+------------------------------------------------------------------+
//| CIndicatorManager - Non-repainting indicator access               |
//| All signal reads use closed bar index 1 unless noted              |
//+------------------------------------------------------------------+
class CIndicatorManager
{
private:
   int    m_fastEmaHandle;
   int    m_slowEmaHandle;
   int    m_htfFastEmaHandle;
   int    m_htfSlowEmaHandle;
   int    m_adxHandle;
   int    m_rsiHandle;
   int    m_atrHandle;
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   ENUM_TIMEFRAMES m_htfTimeframe;
   CLogger *m_logger;

   bool CopyValue(const int handle, const int buffer, const int shift,
                  double &value) const
   {
      double data[];
      ArraySetAsSeries(data, true);
      if(CopyBuffer(handle, buffer, shift, 1, data) != 1)
         return false;
      value = data[0];
      return true;
   }

   bool CopyValues(const int handle, const int buffer, const int shift,
                   const int count, double &values[]) const
   {
      ArraySetAsSeries(values, true);
      if(CopyBuffer(handle, buffer, shift, count, values) < count)
         return false;
      return true;
   }

   double AverageArray(const double &values[]) const
   {
      const int size = ArraySize(values);
      if(size <= 0)
         return 0.0;

      double sum = 0.0;
      for(int i = 0; i < size; i++)
         sum += values[i];
      return sum / size;
   }

public:
   CIndicatorManager(void) :
      m_fastEmaHandle(INVALID_HANDLE),
      m_slowEmaHandle(INVALID_HANDLE),
      m_htfFastEmaHandle(INVALID_HANDLE),
      m_htfSlowEmaHandle(INVALID_HANDLE),
      m_adxHandle(INVALID_HANDLE),
      m_rsiHandle(INVALID_HANDLE),
      m_atrHandle(INVALID_HANDLE),
      m_symbol(""),
      m_timeframe(PERIOD_CURRENT),
      m_htfTimeframe(PERIOD_H4),
      m_logger(NULL)
   {}

   void SetLogger(CLogger *logger) { m_logger = logger; }

   bool Init(const string symbol, const ENUM_TIMEFRAMES timeframe,
             const int fastEma, const int slowEma,
             const int adxPeriod, const int rsiPeriod, const int atrPeriod,
             const ENUM_TIMEFRAMES htfTimeframe,
             const int htfFastEma, const int htfSlowEma)
   {
      m_symbol       = symbol;
      m_timeframe    = timeframe;
      m_htfTimeframe = htfTimeframe;

      m_fastEmaHandle = iMA(m_symbol, m_timeframe, fastEma, 0, MODE_EMA, PRICE_CLOSE);
      m_slowEmaHandle = iMA(m_symbol, m_timeframe, slowEma, 0, MODE_EMA, PRICE_CLOSE);
      m_htfFastEmaHandle = iMA(m_symbol, m_htfTimeframe, htfFastEma, 0, MODE_EMA, PRICE_CLOSE);
      m_htfSlowEmaHandle = iMA(m_symbol, m_htfTimeframe, htfSlowEma, 0, MODE_EMA, PRICE_CLOSE);
      m_adxHandle     = iADX(m_symbol, m_timeframe, adxPeriod);
      m_rsiHandle     = iRSI(m_symbol, m_timeframe, rsiPeriod, PRICE_CLOSE);
      m_atrHandle     = iATR(m_symbol, m_timeframe, atrPeriod);

      if(m_fastEmaHandle == INVALID_HANDLE ||
         m_slowEmaHandle == INVALID_HANDLE ||
         m_htfFastEmaHandle == INVALID_HANDLE ||
         m_htfSlowEmaHandle == INVALID_HANDLE ||
         m_adxHandle     == INVALID_HANDLE ||
         m_rsiHandle     == INVALID_HANDLE ||
         m_atrHandle     == INVALID_HANDLE)
      {
         if(m_logger != NULL)
            m_logger.Error("Failed to create one or more indicator handles.");
         return false;
      }

      if(m_logger != NULL)
         m_logger.Info("Indicators initialized successfully (LTF + HTF).");

      return true;
   }

   void Deinit(void)
   {
      if(m_fastEmaHandle     != INVALID_HANDLE) IndicatorRelease(m_fastEmaHandle);
      if(m_slowEmaHandle     != INVALID_HANDLE) IndicatorRelease(m_slowEmaHandle);
      if(m_htfFastEmaHandle  != INVALID_HANDLE) IndicatorRelease(m_htfFastEmaHandle);
      if(m_htfSlowEmaHandle  != INVALID_HANDLE) IndicatorRelease(m_htfSlowEmaHandle);
      if(m_adxHandle         != INVALID_HANDLE) IndicatorRelease(m_adxHandle);
      if(m_rsiHandle         != INVALID_HANDLE) IndicatorRelease(m_rsiHandle);
      if(m_atrHandle         != INVALID_HANDLE) IndicatorRelease(m_atrHandle);

      m_fastEmaHandle    = INVALID_HANDLE;
      m_slowEmaHandle    = INVALID_HANDLE;
      m_htfFastEmaHandle = INVALID_HANDLE;
      m_htfSlowEmaHandle = INVALID_HANDLE;
      m_adxHandle        = INVALID_HANDLE;
      m_rsiHandle        = INVALID_HANDLE;
      m_atrHandle        = INVALID_HANDLE;
   }

   string GetSymbol(void) const { return m_symbol; }
   ENUM_TIMEFRAMES GetTimeframe(void) const { return m_timeframe; }

   bool GetFastEMA(double &value, const int shift = 1) const
   {
      return CopyValue(m_fastEmaHandle, 0, shift, value);
   }

   bool GetSlowEMA(double &value, const int shift = 1) const
   {
      return CopyValue(m_slowEmaHandle, 0, shift, value);
   }

   bool GetHTFFastEMA(double &value, const int shift = 1) const
   {
      return CopyValue(m_htfFastEmaHandle, 0, shift, value);
   }

   bool GetHTFSlowEMA(double &value, const int shift = 1) const
   {
      return CopyValue(m_htfSlowEmaHandle, 0, shift, value);
   }

   bool GetADX(double &value, const int shift = 1) const
   {
      return CopyValue(m_adxHandle, 0, shift, value);
   }

   bool GetPlusDI(double &value, const int shift = 1) const
   {
      return CopyValue(m_adxHandle, 1, shift, value);
   }

   bool GetMinusDI(double &value, const int shift = 1) const
   {
      return CopyValue(m_adxHandle, 2, shift, value);
   }

   bool GetRSI(double &value, const int shift = 1) const
   {
      return CopyValue(m_rsiHandle, 0, shift, value);
   }

   bool GetATR(double &value, const int shift = 1) const
   {
      return CopyValue(m_atrHandle, 0, shift, value);
   }

   bool GetATRAverage(const int period, double &average) const
   {
      double values[];
      if(!CopyValues(m_atrHandle, 0, 1, period, values))
         return false;
      average = AverageArray(values);
      return average > 0.0;
   }

   bool GetADXAverage(const int period, double &average) const
   {
      double values[];
      if(!CopyValues(m_adxHandle, 0, 1, period, values))
         return false;
      average = AverageArray(values);
      return average > 0.0;
   }

   bool GetBarOHLC(const int shift, double &open, double &high,
                   double &low, double &close) const
   {
      open  = iOpen(m_symbol, m_timeframe, shift);
      high  = iHigh(m_symbol, m_timeframe, shift);
      low   = iLow(m_symbol, m_timeframe, shift);
      close = iClose(m_symbol, m_timeframe, shift);
      return (open > 0.0 && high > 0.0 && low > 0.0 && close > 0.0);
   }
};

//+------------------------------------------------------------------+
//| CMarketStructure - Swing points and Break of Structure (BOS)      |
//| Uses only fully closed bars (shift >= 1 + strength)             |
//+------------------------------------------------------------------+
class CMarketStructure
{
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int             m_lookback;
   int             m_strength;
   CLogger        *m_logger;

   bool IsSwingHigh(const int shift) const
   {
      const double pivot = iHigh(m_symbol, m_timeframe, shift);
      if(pivot <= 0.0)
         return false;

      for(int i = 1; i <= m_strength; i++)
      {
         if(iHigh(m_symbol, m_timeframe, shift - i) >= pivot)
            return false;
         if(iHigh(m_symbol, m_timeframe, shift + i) >= pivot)
            return false;
      }
      return true;
   }

   bool IsSwingLow(const int shift) const
   {
      const double pivot = iLow(m_symbol, m_timeframe, shift);
      if(pivot <= 0.0)
         return false;

      for(int i = 1; i <= m_strength; i++)
      {
         if(iLow(m_symbol, m_timeframe, shift - i) <= pivot)
            return false;
         if(iLow(m_symbol, m_timeframe, shift + i) <= pivot)
            return false;
      }
      return true;
   }

   bool FindLastSwingHigh(double &price, int &shiftFound) const
   {
      price = 0.0;
      shiftFound = -1;

      const int start = 1 + m_strength;
      const int end   = MathMin(m_lookback, iBars(m_symbol, m_timeframe) - m_strength - 1);
      if(end < start)
         return false;

      for(int shift = start; shift <= end; shift++)
      {
         if(IsSwingHigh(shift))
         {
            price = iHigh(m_symbol, m_timeframe, shift);
            shiftFound = shift;
            return true;
         }
      }
      return false;
   }

   bool FindLastSwingLow(double &price, int &shiftFound) const
   {
      price = 0.0;
      shiftFound = -1;

      const int start = 1 + m_strength;
      const int end   = MathMin(m_lookback, iBars(m_symbol, m_timeframe) - m_strength - 1);
      if(end < start)
         return false;

      for(int shift = start; shift <= end; shift++)
      {
         if(IsSwingLow(shift))
         {
            price = iLow(m_symbol, m_timeframe, shift);
            shiftFound = shift;
            return true;
         }
      }
      return false;
   }

public:
   CMarketStructure(void) :
      m_symbol(""),
      m_timeframe(PERIOD_CURRENT),
      m_lookback(50),
      m_strength(2),
      m_logger(NULL)
   {}

   void Init(const string symbol, const ENUM_TIMEFRAMES timeframe,
             const int lookback, const int strength, CLogger *logger)
   {
      m_symbol    = symbol;
      m_timeframe = timeframe;
      m_lookback  = lookback;
      m_strength  = strength;
      m_logger    = logger;
   }

   bool IsBullishBOS(void) const
   {
      double swingHigh = 0.0;
      int swingShift = -1;
      if(!FindLastSwingHigh(swingHigh, swingShift))
         return false;

      const double close1 = iClose(m_symbol, m_timeframe, 1);
      const bool bos = (close1 > swingHigh);

      if(bos && m_logger != NULL)
         m_logger.Debug(StringFormat("Bullish BOS | Close=%.5f > SwingHigh=%.5f (shift=%d)",
                                     close1, swingHigh, swingShift));
      return bos;
   }

   bool IsBearishBOS(void) const
   {
      double swingLow = 0.0;
      int swingShift = -1;
      if(!FindLastSwingLow(swingLow, swingShift))
         return false;

      const double close1 = iClose(m_symbol, m_timeframe, 1);
      const bool bos = (close1 < swingLow);

      if(bos && m_logger != NULL)
         m_logger.Debug(StringFormat("Bearish BOS | Close=%.5f < SwingLow=%.5f (shift=%d)",
                                     close1, swingLow, swingShift));
      return bos;
   }

   bool IsStructureInvalidForLong(void) const
   {
      double swingLow = 0.0;
      int swingShift = -1;
      if(!FindLastSwingLow(swingLow, swingShift))
         return false;

      return (iClose(m_symbol, m_timeframe, 1) < swingLow);
   }

   bool IsStructureInvalidForShort(void) const
   {
      double swingHigh = 0.0;
      int swingShift = -1;
      if(!FindLastSwingHigh(swingHigh, swingShift))
         return false;

      return (iClose(m_symbol, m_timeframe, 1) > swingHigh);
   }
};

//+------------------------------------------------------------------+
//| CPullbackEntryManager - Arms on BOS, enters on pullback confirm   |
//+------------------------------------------------------------------+
class CPullbackEntryManager
{
private:
   ENUM_SETUP_STATE m_state;
   int              m_barsRemaining;
   int              m_maxBars;
   double           m_pullbackAtrZone;
   double           m_rsiCrossLevel;
   bool             m_useCandleConfirm;
   CLogger         *m_logger;

public:
   CPullbackEntryManager(void) :
      m_state(SETUP_NONE),
      m_barsRemaining(0),
      m_maxBars(8),
      m_pullbackAtrZone(0.5),
      m_rsiCrossLevel(50.0),
      m_useCandleConfirm(true),
      m_logger(NULL)
   {}

   void Init(CLogger *logger, const int maxBars, const double pullbackAtrZone,
             const double rsiCrossLevel, const bool useCandleConfirm)
   {
      m_logger           = logger;
      m_maxBars          = maxBars;
      m_pullbackAtrZone  = pullbackAtrZone;
      m_rsiCrossLevel    = rsiCrossLevel;
      m_useCandleConfirm = useCandleConfirm;
      Reset();
   }

   void Reset(void)
   {
      m_state         = SETUP_NONE;
      m_barsRemaining = 0;
   }

   ENUM_SETUP_STATE GetState(void) const { return m_state; }

   void ArmSetup(const ENUM_SIGNAL direction)
   {
      if(direction == SIGNAL_BUY)
         m_state = SETUP_ARMED_BUY;
      else if(direction == SIGNAL_SELL)
         m_state = SETUP_ARMED_SELL;
      else
      {
         Reset();
         return;
      }

      m_barsRemaining = m_maxBars;

      if(m_logger != NULL)
         m_logger.Info(StringFormat("Pullback armed | Direction=%s | MaxBars=%d",
                                    (direction == SIGNAL_BUY ? "BUY" : "SELL"), m_maxBars));
   }

   void DecrementBar(void)
   {
      if(m_state == SETUP_NONE)
         return;

      m_barsRemaining--;
      if(m_barsRemaining <= 0)
      {
         if(m_logger != NULL)
            m_logger.Debug("Pullback setup expired.");
         Reset();
      }
   }

   bool IsPullbackToEMA(const ENUM_SIGNAL direction,
                        CIndicatorManager *indicators) const
   {
      double fastEma = 0.0;
      double atr     = 0.0;
      double low1 = 0.0, high1 = 0.0, open1 = 0.0, close1 = 0.0;

      if(!indicators.GetFastEMA(fastEma, 1) ||
         !indicators.GetATR(atr, 1) ||
         !indicators.GetBarOHLC(1, open1, high1, low1, close1))
         return false;

      const double zone = m_pullbackAtrZone * atr;

      if(direction == SIGNAL_BUY)
      {
         const bool touchedZone = (low1 <= fastEma + zone);
         const bool closedAbove = (close1 > fastEma);
         return touchedZone && closedAbove;
      }

      if(direction == SIGNAL_SELL)
      {
         const bool touchedZone = (high1 >= fastEma - zone);
         const bool closedBelow = (close1 < fastEma);
         return touchedZone && closedBelow;
      }

      return false;
   }

   bool IsRSIMomentumCross(const ENUM_SIGNAL direction,
                           CIndicatorManager *indicators) const
   {
      double rsi1 = 0.0;
      double rsi2 = 0.0;

      if(!indicators.GetRSI(rsi1, 1) || !indicators.GetRSI(rsi2, 2))
         return false;

      if(direction == SIGNAL_BUY)
         return (rsi2 <= m_rsiCrossLevel && rsi1 > m_rsiCrossLevel && rsi1 > rsi2);

      if(direction == SIGNAL_SELL)
         return (rsi2 >= m_rsiCrossLevel && rsi1 < m_rsiCrossLevel && rsi1 < rsi2);

      return false;
   }

   bool IsCandleConfirmed(const ENUM_SIGNAL direction,
                          CIndicatorManager *indicators) const
   {
      if(!m_useCandleConfirm)
         return true;

      double open1 = 0.0, high1 = 0.0, low1 = 0.0, close1 = 0.0;
      double open2 = 0.0, high2 = 0.0, low2 = 0.0, close2 = 0.0;

      if(!indicators.GetBarOHLC(1, open1, high1, low1, close1) ||
         !indicators.GetBarOHLC(2, open2, high2, low2, close2))
         return false;

      if(direction == SIGNAL_BUY)
         return (close1 > open1 && close1 > high2);

      if(direction == SIGNAL_SELL)
         return (close1 < open1 && close1 < low2);

      return false;
   }

   ENUM_SIGNAL TryConfirmEntry(CIndicatorManager *indicators)
   {
      if(m_state == SETUP_NONE || indicators == NULL)
         return SIGNAL_NONE;

      ENUM_SIGNAL direction = SIGNAL_NONE;
      if(m_state == SETUP_ARMED_BUY)
         direction = SIGNAL_BUY;
      else if(m_state == SETUP_ARMED_SELL)
         direction = SIGNAL_SELL;

      if(direction == SIGNAL_NONE)
      {
         Reset();
         return SIGNAL_NONE;
      }

      if(!IsPullbackToEMA(direction, indicators))
      {
         if(m_logger != NULL)
            m_logger.Debug("Pullback not yet complete.");
         return SIGNAL_NONE;
      }

      if(!IsRSIMomentumCross(direction, indicators))
      {
         if(m_logger != NULL)
            m_logger.Debug("RSI momentum cross not confirmed.");
         return SIGNAL_NONE;
      }

      if(!IsCandleConfirmed(direction, indicators))
      {
         if(m_logger != NULL)
            m_logger.Debug("Candle confirmation failed.");
         return SIGNAL_NONE;
      }

      if(m_logger != NULL)
         m_logger.Info(StringFormat("Pullback entry confirmed | Direction=%s",
                                    (direction == SIGNAL_BUY ? "BUY" : "SELL")));

      Reset();
      return direction;
   }
};

//+------------------------------------------------------------------+
//| CSignalEngine - Multi-filter signal generation (non-repainting)   |
//+------------------------------------------------------------------+
class CSignalEngine
{
private:
   CIndicatorManager  *m_indicators;
   CMarketStructure   *m_structure;
   CLogger            *m_logger;
   double              m_adxMin;
   bool                m_useDynamicAdx;
   int                 m_adxAvgPeriod;
   bool                m_requireAdxRising;
   int                 m_atrAvgPeriod;
   double              m_atrMinRatio;
   double              m_atrMaxRatio;
   double              m_minEmaSepAtr;

   bool IsHTFBullish(void) const
   {
      double htfFast = 0.0;
      double htfSlow = 0.0;
      if(!m_indicators.GetHTFFastEMA(htfFast, 1) || !m_indicators.GetHTFSlowEMA(htfSlow, 1))
         return false;
      return (htfFast > htfSlow);
   }

   bool IsHTFBearish(void) const
   {
      double htfFast = 0.0;
      double htfSlow = 0.0;
      if(!m_indicators.GetHTFFastEMA(htfFast, 1) || !m_indicators.GetHTFSlowEMA(htfSlow, 1))
         return false;
      return (htfFast < htfSlow);
   }

   bool PassesATRVolatilityFilter(void) const
   {
      double atr1 = 0.0;
      double atrAvg = 0.0;
      if(!m_indicators.GetATR(atr1, 1) || !m_indicators.GetATRAverage(m_atrAvgPeriod, atrAvg))
         return false;

      if(atr1 < atrAvg * m_atrMinRatio)
      {
         if(m_logger != NULL)
            m_logger.Debug(StringFormat("ATR too low | ATR=%.5f Avg=%.5f", atr1, atrAvg));
         return false;
      }

      if(atr1 > atrAvg * m_atrMaxRatio)
      {
         if(m_logger != NULL)
            m_logger.Debug(StringFormat("ATR too high | ATR=%.5f Avg=%.5f", atr1, atrAvg));
         return false;
      }

      return true;
   }

   bool PassesDynamicADX(double &adxOut) const
   {
      double adx1 = 0.0;
      double adx2 = 0.0;
      double adxAvg = 0.0;

      if(!m_indicators.GetADX(adx1, 1) || !m_indicators.GetADX(adx2, 2))
         return false;

      adxOut = adx1;
      double threshold = m_adxMin;

      if(m_useDynamicAdx)
      {
         if(!m_indicators.GetADXAverage(m_adxAvgPeriod, adxAvg))
            return false;
         threshold = MathMax(m_adxMin, adxAvg * 0.90);
      }

      if(adx1 < threshold)
      {
         if(m_logger != NULL)
            m_logger.Debug(StringFormat("ADX below threshold | ADX=%.2f Min=%.2f", adx1, threshold));
         return false;
      }

      if(m_requireAdxRising && adx1 <= adx2)
      {
         if(m_logger != NULL)
            m_logger.Debug(StringFormat("ADX not rising | ADX[1]=%.2f ADX[2]=%.2f", adx1, adx2));
         return false;
      }

      return true;
   }

   bool IsRangingMarket(void) const
   {
      double fastEma = 0.0;
      double slowEma = 0.0;
      double atr     = 0.0;
      double adx1    = 0.0;

      if(!m_indicators.GetFastEMA(fastEma, 1) ||
         !m_indicators.GetSlowEMA(slowEma, 1) ||
         !m_indicators.GetATR(atr, 1) ||
         !m_indicators.GetADX(adx1, 1))
         return true;

      if(atr <= 0.0)
         return true;

      const double emaSep = MathAbs(fastEma - slowEma) / atr;
      if(emaSep < m_minEmaSepAtr)
      {
         if(m_logger != NULL)
            m_logger.Debug(StringFormat("Range filter | EMA sep/ATR=%.2f < %.2f", emaSep, m_minEmaSepAtr));
         return true;
      }

      if(adx1 < m_adxMin)
         return true;

      return false;
   }

   bool PassesLTFTrend(const ENUM_SIGNAL direction) const
   {
      double fastEma = 0.0;
      double slowEma = 0.0;
      double plusDi  = 0.0;
      double minusDi = 0.0;

      if(!m_indicators.GetFastEMA(fastEma, 1) ||
         !m_indicators.GetSlowEMA(slowEma, 1) ||
         !m_indicators.GetPlusDI(plusDi, 1) ||
         !m_indicators.GetMinusDI(minusDi, 1))
         return false;

      if(direction == SIGNAL_BUY)
         return (fastEma > slowEma && plusDi > minusDi);

      if(direction == SIGNAL_SELL)
         return (fastEma < slowEma && minusDi > plusDi);

      return false;
   }

public:
   CSignalEngine(void) :
      m_indicators(NULL),
      m_structure(NULL),
      m_logger(NULL),
      m_adxMin(22.0),
      m_useDynamicAdx(true),
      m_adxAvgPeriod(14),
      m_requireAdxRising(true),
      m_atrAvgPeriod(20),
      m_atrMinRatio(0.85),
      m_atrMaxRatio(2.50),
      m_minEmaSepAtr(0.35)
   {}

   void Init(CIndicatorManager *indicators, CMarketStructure *structure, CLogger *logger,
             const double adxMin, const bool useDynamicAdx, const int adxAvgPeriod,
             const bool requireAdxRising, const int atrAvgPeriod,
             const double atrMinRatio, const double atrMaxRatio,
             const double minEmaSepAtr)
   {
      m_indicators       = indicators;
      m_structure        = structure;
      m_logger           = logger;
      m_adxMin           = adxMin;
      m_useDynamicAdx    = useDynamicAdx;
      m_adxAvgPeriod     = adxAvgPeriod;
      m_requireAdxRising = requireAdxRising;
      m_atrAvgPeriod     = atrAvgPeriod;
      m_atrMinRatio      = atrMinRatio;
      m_atrMaxRatio      = atrMaxRatio;
      m_minEmaSepAtr     = minEmaSepAtr;
   }

   bool PassesCoreFilters(void) const
   {
      if(m_indicators == NULL)
         return false;

      double adx = 0.0;
      if(!PassesATRVolatilityFilter())
         return false;
      if(!PassesDynamicADX(adx))
         return false;
      if(IsRangingMarket())
         return false;

      return true;
   }

   ENUM_SIGNAL EvaluateSetup(void) const
   {
      if(m_indicators == NULL || m_structure == NULL)
         return SIGNAL_NONE;

      if(!PassesCoreFilters())
         return SIGNAL_NONE;

      if(m_structure.IsBullishBOS() && IsHTFBullish() && PassesLTFTrend(SIGNAL_BUY))
      {
         if(m_logger != NULL)
            m_logger.Info("Setup detected: Bullish BOS + HTF/LTF trend aligned.");
         return SIGNAL_BUY;
      }

      if(m_structure.IsBearishBOS() && IsHTFBearish() && PassesLTFTrend(SIGNAL_SELL))
      {
         if(m_logger != NULL)
            m_logger.Info("Setup detected: Bearish BOS + HTF/LTF trend aligned.");
         return SIGNAL_SELL;
      }

      return SIGNAL_NONE;
   }

   bool ValidateArmedSetup(const ENUM_SIGNAL direction) const
   {
      if(direction == SIGNAL_NONE)
         return false;

      if(!PassesCoreFilters())
         return false;

      if(direction == SIGNAL_BUY)
         return (IsHTFBullish() && PassesLTFTrend(SIGNAL_BUY));

      if(direction == SIGNAL_SELL)
         return (IsHTFBearish() && PassesLTFTrend(SIGNAL_SELL));

      return false;
   }
};

//+------------------------------------------------------------------+
//| CExitManager - Structure / momentum exit logic                    |
//| Separate from CPositionManager (trailing / break-even unchanged)  |
//+------------------------------------------------------------------+
class CExitManager
{
private:
   CTrade           m_trade;
   CSymbolInfo      m_symbol;
   CIndicatorManager *m_indicators;
   CMarketStructure *m_structure;
   CLogger          *m_logger;
   ulong             m_magic;
   double            m_rsiCrossLevel;
   bool              m_useStructureExit;
   bool              m_useRsiExit;
   bool              m_useOppositeBosExit;

   bool HasOurPosition(ulong &ticket, ENUM_POSITION_TYPE &type) const
   {
      ticket = 0;
      const string symbolName = m_symbol.Name();

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         const ulong posTicket = PositionGetTicket(i);
         if(posTicket == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != symbolName)
            continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;

         ticket = posTicket;
         type   = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         return true;
      }
      return false;
   }

   bool IsRSIReversalExit(const ENUM_POSITION_TYPE type) const
   {
      if(!m_useRsiExit || m_indicators == NULL)
         return false;

      double rsi1 = 0.0;
      double rsi2 = 0.0;
      if(!m_indicators.GetRSI(rsi1, 1) || !m_indicators.GetRSI(rsi2, 2))
         return false;

      if(type == POSITION_TYPE_BUY)
         return (rsi2 >= m_rsiCrossLevel && rsi1 < m_rsiCrossLevel);

      if(type == POSITION_TYPE_SELL)
         return (rsi2 <= m_rsiCrossLevel && rsi1 > m_rsiCrossLevel);

      return false;
   }

public:
   CExitManager(void) :
      m_indicators(NULL),
      m_structure(NULL),
      m_logger(NULL),
      m_magic(0),
      m_rsiCrossLevel(50.0),
      m_useStructureExit(true),
      m_useRsiExit(true),
      m_useOppositeBosExit(true)
   {}

   void Init(CLogger *logger, const ulong magic, CIndicatorManager *indicators,
             CMarketStructure *structure, const double rsiCrossLevel,
             const bool useStructureExit, const bool useRsiExit,
             const bool useOppositeBosExit)
   {
      m_logger             = logger;
      m_magic              = magic;
      m_indicators         = indicators;
      m_structure          = structure;
      m_rsiCrossLevel      = rsiCrossLevel;
      m_useStructureExit   = useStructureExit;
      m_useRsiExit         = useRsiExit;
      m_useOppositeBosExit = useOppositeBosExit;

      m_trade.SetExpertMagicNumber(m_magic);
      m_trade.SetDeviationInPoints(20);
   }

   bool RefreshSymbol(const string symbol)
   {
      if(!m_symbol.Name(symbol))
         return false;
      m_trade.SetTypeFilling(GetFillingMode(symbol));
      return true;
   }

   bool CheckAndExit(void)
   {
      ulong ticket = 0;
      ENUM_POSITION_TYPE type = POSITION_TYPE_BUY;

      if(!HasOurPosition(ticket, type))
         return false;

      string reason = "";

      if(m_useStructureExit && m_structure != NULL)
      {
         if(type == POSITION_TYPE_BUY && m_structure.IsStructureInvalidForLong())
            reason = "Structure invalidation (long)";
         else if(type == POSITION_TYPE_SELL && m_structure.IsStructureInvalidForShort())
            reason = "Structure invalidation (short)";
      }

      if(reason == "" && m_useOppositeBosExit && m_structure != NULL)
      {
         if(type == POSITION_TYPE_BUY && m_structure.IsBearishBOS())
            reason = "Opposite bearish BOS";
         else if(type == POSITION_TYPE_SELL && m_structure.IsBullishBOS())
            reason = "Opposite bullish BOS";
      }

      if(reason == "" && IsRSIReversalExit(type))
         reason = "RSI momentum reversal";

      if(reason == "")
         return false;

      if(!m_trade.PositionClose(ticket))
      {
         if(m_logger != NULL)
            m_logger.Error(StringFormat("Exit close failed: %s", m_trade.ResultRetcodeDescription()));
         return false;
      }

      if(m_logger != NULL)
         m_logger.Info(StringFormat("Position closed | Ticket=%I64u Reason=%s", ticket, reason));

      return true;
   }
};

//+------------------------------------------------------------------+
//| CRiskManager - Fixed lot and risk-percent sizing                  |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   CSymbolInfo  m_symbol;
   CAccountInfo m_account;
   CLogger     *m_logger;
   ENUM_LOT_MODE m_lotMode;
   double        m_fixedLot;
   double        m_riskPercent;

   double NormalizeLot(const double lot) const
   {
      double minLot  = m_symbol.LotsMin();
      double maxLot  = m_symbol.LotsMax();
      double lotStep = m_symbol.LotsStep();

      if(lotStep <= 0.0)
         return 0.0;

      double normalized = MathFloor(lot / lotStep) * lotStep;
      normalized = MathMax(minLot, MathMin(maxLot, normalized));

      int digits = (int)MathCeil(-MathLog10(lotStep));
      return NormalizeDouble(normalized, digits);
   }

public:
   CRiskManager(void) :
      m_logger(NULL),
      m_lotMode(LOT_MODE_RISK_PERCENT),
      m_fixedLot(0.10),
      m_riskPercent(1.0)
   {}

   void Init(CLogger *logger, const ENUM_LOT_MODE lotMode,
             const double fixedLot, const double riskPercent)
   {
      m_logger      = logger;
      m_lotMode     = lotMode;
      m_fixedLot    = fixedLot;
      m_riskPercent = riskPercent;
   }

   bool RefreshSymbol(const string symbol)
   {
      return m_symbol.Name(symbol);
   }

   double CalculateLotSize(const double stopLossDistance)
   {
      if(!m_symbol.RefreshRates())
      {
         if(m_logger != NULL)
            m_logger.Error("Cannot refresh symbol rates for lot calculation.");
         return 0.0;
      }

      if(m_lotMode == LOT_MODE_FIXED)
      {
         double lot = NormalizeLot(m_fixedLot);
         if(m_logger != NULL)
            m_logger.Debug(StringFormat("Fixed lot size: %.2f", lot));
         return lot;
      }

      if(stopLossDistance <= 0.0)
      {
         if(m_logger != NULL)
            m_logger.Error("Invalid stop loss distance for risk calculation.");
         return 0.0;
      }

      double balance   = m_account.Balance();
      double riskMoney = balance * m_riskPercent / 100.0;

      double tickValue = m_symbol.TickValue();
      double tickSize  = m_symbol.TickSize();

      if(tickValue <= 0.0 || tickSize <= 0.0)
      {
         if(m_logger != NULL)
            m_logger.Error("Invalid tick value or tick size.");
         return 0.0;
      }

      double moneyPerLot = (stopLossDistance / tickSize) * tickValue;
      if(moneyPerLot <= 0.0)
         return 0.0;

      double lot = riskMoney / moneyPerLot;
      lot = NormalizeLot(lot);

      if(m_logger != NULL)
         m_logger.Debug(StringFormat("Risk lot: %.2f (Risk=%.2f%%, SL dist=%.5f)",
                                     lot, m_riskPercent, stopLossDistance));
      return lot;
   }
};

//+------------------------------------------------------------------+
//| CFilterManager - Spread and session filters                       |
//+------------------------------------------------------------------+
class CFilterManager
{
private:
   CSymbolInfo m_symbol;
   CLogger    *m_logger;
   int         m_maxSpreadPoints;
   bool        m_useSession;
   int         m_startHour;
   int         m_startMinute;
   int         m_endHour;
   int         m_endMinute;

   int TimeToMinutes(const int hour, const int minute) const
   {
      return hour * 60 + minute;
   }

public:
   CFilterManager(void) :
      m_logger(NULL),
      m_maxSpreadPoints(30),
      m_useSession(true),
      m_startHour(8),
      m_startMinute(0),
      m_endHour(20),
      m_endMinute(0)
   {}

   void Init(CLogger *logger, const int maxSpreadPoints,
             const bool useSession, const int startHour, const int startMinute,
             const int endHour, const int endMinute)
   {
      m_logger           = logger;
      m_maxSpreadPoints  = maxSpreadPoints;
      m_useSession       = useSession;
      m_startHour        = startHour;
      m_startMinute      = startMinute;
      m_endHour          = endHour;
      m_endMinute        = endMinute;
   }

   bool RefreshSymbol(const string symbol)
   {
      return m_symbol.Name(symbol);
   }

   bool IsSpreadAcceptable(void) const
   {
      const long spread = SymbolInfoInteger(m_symbol.Name(), SYMBOL_SPREAD);
      if(spread > m_maxSpreadPoints)
      {
         if(m_logger != NULL)
            m_logger.Debug(StringFormat("Spread filter blocked: %d > %d points",
                                        (int)spread, m_maxSpreadPoints));
         return false;
      }
      return true;
   }

   bool IsWithinSession(void) const
   {
      if(!m_useSession)
         return true;

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);

      const int currentMinutes = TimeToMinutes(dt.hour, dt.min);
      const int startMinutes   = TimeToMinutes(m_startHour, m_startMinute);
      const int endMinutes     = TimeToMinutes(m_endHour, m_endMinute);

      bool inSession = false;

      // Supports sessions crossing midnight
      if(startMinutes <= endMinutes)
         inSession = (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
      else
         inSession = (currentMinutes >= startMinutes || currentMinutes <= endMinutes);

      if(!inSession && m_logger != NULL)
         m_logger.Debug(StringFormat("Session filter blocked at %02d:%02d", dt.hour, dt.min));

      return inSession;
   }

   bool PassAllFilters(void) const
   {
      return IsSpreadAcceptable() && IsWithinSession();
   }
};

//+------------------------------------------------------------------+
//| CPositionManager - Trailing stop and break-even                   |
//+------------------------------------------------------------------+
class CPositionManager
{
private:
   CTrade        m_trade;
   CSymbolInfo   m_symbol;
   CPositionInfo m_position;
   CLogger      *m_logger;
   ulong         m_magic;
   bool          m_useTrailing;
   double        m_trailStartAtr;
   double        m_trailStepAtr;
   bool          m_useBreakEven;
   double        m_beTriggerAtr;
   int           m_beOffsetPoints;

   bool SelectOurPosition(void)
   {
      if(!m_position.Select(m_symbol.Name()))
         return false;
      if(m_position.Magic() != m_magic)
         return false;
      return true;
   }

   double NormalizePrice(const double price) const
   {
      return NormalizeDouble(price, m_symbol.Digits());
   }

   bool ModifyStopLoss(const double newSl, const string reason)
   {
      if(!SelectOurPosition())
         return false;

      const double currentTp = m_position.TakeProfit();
      const double currentSl = m_position.StopLoss();

      if(MathAbs(newSl - currentSl) < m_symbol.Point())
         return false;

      if(!m_trade.PositionModify(m_position.Ticket(), newSl, currentTp))
      {
         if(m_logger != NULL)
            m_logger.Error(StringFormat("%s modify failed: %s", reason, m_trade.ResultRetcodeDescription()));
         return false;
      }

      if(m_logger != NULL)
         m_logger.Info(StringFormat("%s applied | Ticket=%I64u SL=%.5f",
                                    reason, m_position.Ticket(), newSl));
      return true;
   }

public:
   CPositionManager(void) :
      m_logger(NULL),
      m_magic(0),
      m_useTrailing(true),
      m_trailStartAtr(1.5),
      m_trailStepAtr(0.5),
      m_useBreakEven(true),
      m_beTriggerAtr(1.0),
      m_beOffsetPoints(5)
   {}

   void Init(CLogger *logger, const ulong magic,
             const bool useTrailing, const double trailStartAtr, const double trailStepAtr,
             const bool useBreakEven, const double beTriggerAtr, const int beOffsetPoints)
   {
      m_logger           = logger;
      m_magic            = magic;
      m_useTrailing      = useTrailing;
      m_trailStartAtr    = trailStartAtr;
      m_trailStepAtr     = trailStepAtr;
      m_useBreakEven     = useBreakEven;
      m_beTriggerAtr     = beTriggerAtr;
      m_beOffsetPoints   = beOffsetPoints;

      m_trade.SetExpertMagicNumber(m_magic);
      m_trade.SetDeviationInPoints(20);
   }

   bool RefreshSymbol(const string symbol)
   {
      if(!m_symbol.Name(symbol))
         return false;
      m_trade.SetTypeFilling(GetFillingMode(symbol));
      return true;
   }

   bool HasOpenPosition(void) const
   {
      const string symbolName = m_symbol.Name();

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != symbolName)
            continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;
         return true;
      }
      return false;
   }

   void ManageOpenPosition(const double atrValue)
   {
      if(atrValue <= 0.0)
         return;

      if(!m_symbol.RefreshRates())
         return;

      if(!SelectOurPosition())
         return;

      const ENUM_POSITION_TYPE type   = m_position.PositionType();
      const double entryPrice         = m_position.PriceOpen();
      const double currentSl          = m_position.StopLoss();
      const double point              = m_symbol.Point();
      const double bid                = m_symbol.Bid();
      const double ask                = m_symbol.Ask();

      // Break-even management
      if(m_useBreakEven)
      {
         const double triggerDistance = m_beTriggerAtr * atrValue;
         const double offset          = m_beOffsetPoints * point;

         if(type == POSITION_TYPE_BUY)
         {
            if(bid - entryPrice >= triggerDistance)
            {
               const double beSl = NormalizePrice(entryPrice + offset);
               if(currentSl < beSl)
                  ModifyStopLoss(beSl, "Break-even");
            }
         }
         else if(type == POSITION_TYPE_SELL)
         {
            if(entryPrice - ask >= triggerDistance)
            {
               const double beSl = NormalizePrice(entryPrice - offset);
               if(currentSl == 0.0 || currentSl > beSl)
                  ModifyStopLoss(beSl, "Break-even");
            }
         }
      }

      // Trailing stop management
      if(m_useTrailing)
      {
         const double trailStart = m_trailStartAtr * atrValue;
         const double trailStep  = m_trailStepAtr * atrValue;

         if(type == POSITION_TYPE_BUY)
         {
            if(bid - entryPrice >= trailStart)
            {
               const double newSl = NormalizePrice(bid - trailStep);
               if(newSl > currentSl && newSl < bid)
                  ModifyStopLoss(newSl, "Trailing stop");
            }
         }
         else if(type == POSITION_TYPE_SELL)
         {
            if(entryPrice - ask >= trailStart)
            {
               const double newSl = NormalizePrice(ask + trailStep);
               if(currentSl == 0.0 || (newSl < currentSl && newSl > ask))
                  ModifyStopLoss(newSl, "Trailing stop");
            }
         }
      }
   }
};

//+------------------------------------------------------------------+
//| CTradeExecutor - Order execution via CTrade                       |
//+------------------------------------------------------------------+
class CTradeExecutor
{
private:
   CTrade        m_trade;
   CSymbolInfo   m_symbol;
   CLogger      *m_logger;
   ulong         m_magic;
   string        m_comment;
   double        m_slMultiplier;
   double        m_tpMultiplier;

   bool ValidateStops(const ENUM_ORDER_TYPE orderType,
                      const double price, double &sl, double &tp) const
   {
      const double point     = m_symbol.Point();
      const int    stopsLevel = (int)m_symbol.StopsLevel();

      if(stopsLevel > 0)
      {
         const double minDistance = stopsLevel * point;
         if(orderType == ORDER_TYPE_BUY)
         {
            if(price - sl < minDistance) sl = NormalizeDouble(price - minDistance, m_symbol.Digits());
            if(tp - price < minDistance) tp = NormalizeDouble(price + minDistance, m_symbol.Digits());
         }
         else
         {
            if(sl - price < minDistance) sl = NormalizeDouble(price + minDistance, m_symbol.Digits());
            if(price - tp < minDistance) tp = NormalizeDouble(price - minDistance, m_symbol.Digits());
         }
      }
      return true;
   }

public:
   CTradeExecutor(void) :
      m_logger(NULL),
      m_magic(0),
      m_comment("ProEA_v1"),
      m_slMultiplier(2.0),
      m_tpMultiplier(3.0)
   {}

   void Init(CLogger *logger, const ulong magic, const string comment,
             const double slMultiplier, const double tpMultiplier)
   {
      m_logger       = logger;
      m_magic        = magic;
      m_comment      = comment;
      m_slMultiplier = slMultiplier;
      m_tpMultiplier = tpMultiplier;

      m_trade.SetExpertMagicNumber(m_magic);
      m_trade.SetDeviationInPoints(20);
   }

   bool RefreshSymbol(const string symbol)
   {
      if(!m_symbol.Name(symbol))
         return false;
      m_trade.SetTypeFilling(GetFillingMode(symbol));
      return true;
   }

   bool OpenTrade(const ENUM_SIGNAL signal, const double lotSize, const double atrValue)
   {
      if(signal == SIGNAL_NONE || lotSize <= 0.0 || atrValue <= 0.0)
         return false;

      if(!m_symbol.RefreshRates())
      {
         if(m_logger != NULL)
            m_logger.Error("Cannot refresh rates before opening trade.");
         return false;
      }

      const double slDistance = m_slMultiplier * atrValue;
      const double tpDistance = m_tpMultiplier * atrValue;

      if(signal == SIGNAL_BUY)
      {
         const double ask = m_symbol.Ask();
         double sl = NormalizeDouble(ask - slDistance, m_symbol.Digits());
         double tp = NormalizeDouble(ask + tpDistance, m_symbol.Digits());
         ValidateStops(ORDER_TYPE_BUY, ask, sl, tp);

         if(!m_trade.Buy(lotSize, m_symbol.Name(), ask, sl, tp, m_comment))
         {
            if(m_logger != NULL)
               m_logger.Error(StringFormat("BUY failed: %s", m_trade.ResultRetcodeDescription()));
            return false;
         }

         if(m_logger != NULL)
            m_logger.Info(StringFormat("BUY opened | Lot=%.2f Price=%.5f SL=%.5f TP=%.5f",
                                       lotSize, ask, sl, tp));
         return true;
      }

      if(signal == SIGNAL_SELL)
      {
         const double bid = m_symbol.Bid();
         double sl = NormalizeDouble(bid + slDistance, m_symbol.Digits());
         double tp = NormalizeDouble(bid - tpDistance, m_symbol.Digits());
         ValidateStops(ORDER_TYPE_SELL, bid, sl, tp);

         if(!m_trade.Sell(lotSize, m_symbol.Name(), bid, sl, tp, m_comment))
         {
            if(m_logger != NULL)
               m_logger.Error(StringFormat("SELL failed: %s", m_trade.ResultRetcodeDescription()));
            return false;
         }

         if(m_logger != NULL)
            m_logger.Info(StringFormat("SELL opened | Lot=%.2f Price=%.5f SL=%.5f TP=%.5f",
                                       lotSize, bid, sl, tp));
         return true;
      }

      return false;
   }
};

//+------------------------------------------------------------------+
//| CExpertAdvisor - Main orchestrator                                |
//+------------------------------------------------------------------+
class CExpertAdvisor
{
private:
   CLogger               m_logger;
   CIndicatorManager     m_indicators;
   CMarketStructure      m_structure;
   CSignalEngine         m_signals;
   CPullbackEntryManager m_pullback;
   CExitManager          m_exits;
   CRiskManager          m_risk;
   CFilterManager        m_filters;
   CPositionManager      m_positions;
   CTradeExecutor        m_executor;

   string             m_symbol;
   ENUM_TIMEFRAMES    m_timeframe;
   datetime           m_lastBarTime;
   datetime           m_lastExitBarTime;
   double             m_slMultiplier;
   double             m_tpMultiplier;

   bool IsNewBar(void)
   {
      datetime barTime = iTime(m_symbol, m_timeframe, 0);
      if(barTime == 0)
         return false;

      if(barTime != m_lastBarTime)
      {
         m_lastBarTime = barTime;
         return true;
      }
      return false;
   }

   bool ValidateInputs(void) const
   {
      if(InpFastEMA <= 0 || InpSlowEMA <= 0 || InpFastEMA >= InpSlowEMA)
      {
         m_logger.Error("Invalid EMA periods: Fast EMA must be less than Slow EMA.");
         return false;
      }
      if(InpHTFFastEMA <= 0 || InpHTFSlowEMA <= 0 || InpHTFFastEMA >= InpHTFSlowEMA)
      {
         m_logger.Error("Invalid HTF EMA periods: Fast EMA must be less than Slow EMA.");
         return false;
      }
      if(InpADXPeriod <= 0 || InpRSIPeriod <= 0 || InpATRPeriod <= 0)
      {
         m_logger.Error("Indicator periods must be greater than zero.");
         return false;
      }
      if(InpSwingStrength <= 0 || InpSwingLookback <= InpSwingStrength * 2)
      {
         m_logger.Error("Invalid swing parameters.");
         return false;
      }
      if(InpPullbackMaxBars <= 0)
      {
         m_logger.Error("Pullback max bars must be greater than zero.");
         return false;
      }
      if(InpATRAvgPeriod <= 0 || InpADXAvgPeriod <= 0)
      {
         m_logger.Error("Average periods must be greater than zero.");
         return false;
      }
      if(InpATRMinRatio <= 0.0 || InpATRMaxRatio <= InpATRMinRatio)
      {
         m_logger.Error("Invalid ATR ratio parameters.");
         return false;
      }
      if(InpSL_ATR_Multiplier <= 0.0 || InpTP_ATR_Multiplier <= 0.0)
      {
         m_logger.Error("ATR multipliers must be greater than zero.");
         return false;
      }
      if(InpFixedLot <= 0.0 && InpLotMode == LOT_MODE_FIXED)
      {
         m_logger.Error("Fixed lot must be greater than zero.");
         return false;
      }
      if(InpRiskPercent <= 0.0 && InpLotMode == LOT_MODE_RISK_PERCENT)
      {
         m_logger.Error("Risk percent must be greater than zero.");
         return false;
      }
      return true;
   }

public:
   CExpertAdvisor(void) :
      m_symbol(_Symbol),
      m_timeframe(PERIOD_CURRENT),
      m_lastBarTime(0),
      m_lastExitBarTime(0),
      m_slMultiplier(2.0),
      m_tpMultiplier(3.0)
   {}

   ENUM_SIGNAL GetArmedDirection(void) const
   {
      if(m_pullback.GetState() == SETUP_ARMED_BUY)
         return SIGNAL_BUY;
      if(m_pullback.GetState() == SETUP_ARMED_SELL)
         return SIGNAL_SELL;
      return SIGNAL_NONE;
   }

   bool Init(void)
   {
      m_symbol    = _Symbol;
      m_timeframe = PERIOD_CURRENT;
      m_lastBarTime = iTime(m_symbol, m_timeframe, 0);
      m_lastExitBarTime = 0;
      m_slMultiplier = InpSL_ATR_Multiplier;
      m_tpMultiplier = InpTP_ATR_Multiplier;

      m_logger.Init(InpLogLevel, "ProEA");
      m_logger.Info("Initializing Expert Advisor v2.00...");

      if(!ValidateInputs())
         return false;

      m_indicators.SetLogger(GetPointer(m_logger));
      if(!m_indicators.Init(m_symbol, m_timeframe,
                            InpFastEMA, InpSlowEMA,
                            InpADXPeriod, InpRSIPeriod, InpATRPeriod,
                            InpHTFTimeframe, InpHTFFastEMA, InpHTFSlowEMA))
         return false;

      m_structure.Init(m_symbol, m_timeframe,
                       InpSwingLookback, InpSwingStrength,
                       GetPointer(m_logger));

      m_signals.Init(GetPointer(m_indicators), GetPointer(m_structure), GetPointer(m_logger),
                     InpADXMinLevel, InpUseDynamicADX, InpADXAvgPeriod,
                     InpRequireADXRising, InpATRAvgPeriod,
                     InpATRMinRatio, InpATRMaxRatio, InpMinEMASeparationATR);

      m_pullback.Init(GetPointer(m_logger), InpPullbackMaxBars, InpPullbackATRZone,
                      InpRSICrossLevel, InpUseCandleConfirm);

      m_exits.Init(GetPointer(m_logger), InpMagicNumber,
                   GetPointer(m_indicators), GetPointer(m_structure),
                   InpRSICrossLevel, InpUseStructureExit,
                   InpUseRSIExit, InpUseOppositeBOSExit);
      if(!m_exits.RefreshSymbol(m_symbol))
      {
         m_logger.Error("Failed to bind exit manager to symbol.");
         return false;
      }

      m_risk.Init(GetPointer(m_logger), InpLotMode, InpFixedLot, InpRiskPercent);
      if(!m_risk.RefreshSymbol(m_symbol))
      {
         m_logger.Error("Failed to bind risk manager to symbol.");
         return false;
      }

      m_filters.Init(GetPointer(m_logger), InpMaxSpreadPoints,
                     InpUseSessionFilter,
                     InpSessionStartHour, InpSessionStartMinute,
                     InpSessionEndHour, InpSessionEndMinute);
      if(!m_filters.RefreshSymbol(m_symbol))
      {
         m_logger.Error("Failed to bind filter manager to symbol.");
         return false;
      }

      m_positions.Init(GetPointer(m_logger), InpMagicNumber,
                       InpUseTrailingStop, InpTrailStartATR, InpTrailStepATR,
                       InpUseBreakEven, InpBreakEvenTriggerATR, InpBreakEvenOffsetPoints);
      if(!m_positions.RefreshSymbol(m_symbol))
      {
         m_logger.Error("Failed to bind position manager to symbol.");
         return false;
      }

      m_executor.Init(GetPointer(m_logger), InpMagicNumber, InpTradeComment,
                      InpSL_ATR_Multiplier, InpTP_ATR_Multiplier);
      if(!m_executor.RefreshSymbol(m_symbol))
      {
         m_logger.Error("Failed to bind trade executor to symbol.");
         return false;
      }

      m_logger.Info(StringFormat("EA ready | Symbol=%s Magic=%I64u | Modules: SignalEngine, Structure, Pullback, Exit",
                                 m_symbol, InpMagicNumber));
      return true;
   }

   void Deinit(void)
   {
      m_pullback.Reset();
      m_indicators.Deinit();
      m_logger.Info("Expert Advisor deinitialized.");
   }

   void OnTick(void)
   {
      double atrValue = 0.0;

      // --- Trade management: signal-based exit (every tick) ---
      if(m_exits.CheckAndExit())
      {
         m_lastExitBarTime = iTime(m_symbol, m_timeframe, 0);
         m_pullback.Reset();
         m_logger.Debug("Exit triggered - pullback state cleared.");
      }

      // --- Trade management: trailing stop / break-even (unchanged) ---
      if(m_indicators.GetATR(atrValue) && m_positions.HasOpenPosition())
         m_positions.ManageOpenPosition(atrValue);

      // --- Entry logic: new closed candle only ---
      if(!IsNewBar())
         return;

      m_logger.Debug("New bar - evaluating pullback and setup conditions.");

      if(m_positions.HasOpenPosition())
      {
         m_logger.Debug("Entry skipped: position already open for this symbol.");
         return;
      }

      if(m_lastExitBarTime == m_lastBarTime)
      {
         m_logger.Debug("Entry skipped: exit occurred on this bar.");
         return;
      }

      if(!m_filters.PassAllFilters())
         return;

      ENUM_SIGNAL signal = SIGNAL_NONE;

      // --- Pullback path: confirm armed setup from prior BOS ---
      if(m_pullback.GetState() != SETUP_NONE)
      {
         m_pullback.DecrementBar();

         const ENUM_SIGNAL armedDir = GetArmedDirection();
         if(armedDir != SIGNAL_NONE && m_pullback.GetState() != SETUP_NONE)
         {
            if(m_signals.ValidateArmedSetup(armedDir))
               signal = m_pullback.TryConfirmEntry(GetPointer(m_indicators));
            else
            {
               m_pullback.Reset();
               m_logger.Debug("Armed setup invalidated - trend/filter conditions lost.");
            }
         }
      }

      // --- Setup path: arm new BOS setup when no active pullback ---
      if(signal == SIGNAL_NONE && m_pullback.GetState() == SETUP_NONE)
      {
         const ENUM_SIGNAL setup = m_signals.EvaluateSetup();
         if(setup != SIGNAL_NONE)
            m_pullback.ArmSetup(setup);
      }

      if(signal == SIGNAL_NONE)
         return;

      if(!m_indicators.GetATR(atrValue) || atrValue <= 0.0)
      {
         m_logger.Error("ATR unavailable for trade execution.");
         return;
      }

      const double slDistance = m_slMultiplier * atrValue;
      const double lotSize    = m_risk.CalculateLotSize(slDistance);
      if(lotSize <= 0.0)
      {
         m_logger.Error("Lot size calculation returned zero.");
         return;
      }

      m_executor.OpenTrade(signal, lotSize, atrValue);
   }
};

//+------------------------------------------------------------------+
//| Global EA instance                                                |
//+------------------------------------------------------------------+
CExpertAdvisor g_ea;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit(void)
{
   if(!g_ea.Init())
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_ea.Deinit();
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick(void)
{
   g_ea.OnTick();
}
//+------------------------------------------------------------------+
