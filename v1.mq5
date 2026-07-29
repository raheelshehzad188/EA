//+------------------------------------------------------------------+
//|                                                         v1.mq5   |
//|                        Professional Trend-Following Expert Advisor|
//+------------------------------------------------------------------+
#property copyright "Professional EA"
#property version   "1.00"

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

input group "=== ADX Confirmation ==="
input int            InpADXPeriod          = 14;           // ADX period
input double         InpADXMinLevel        = 25.0;         // Minimum ADX level

input group "=== RSI Confirmation ==="
input int            InpRSIPeriod          = 14;           // RSI period
input double         InpRSIBuyLevel        = 50.0;         // RSI minimum for BUY
input double         InpRSISellLevel       = 50.0;         // RSI maximum for SELL

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
//| All signal reads use closed bar index 1                           |
//+------------------------------------------------------------------+
class CIndicatorManager
{
private:
   int    m_fastEmaHandle;
   int    m_slowEmaHandle;
   int    m_adxHandle;
   int    m_rsiHandle;
   int    m_atrHandle;
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
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

public:
   CIndicatorManager(void) :
      m_fastEmaHandle(INVALID_HANDLE),
      m_slowEmaHandle(INVALID_HANDLE),
      m_adxHandle(INVALID_HANDLE),
      m_rsiHandle(INVALID_HANDLE),
      m_atrHandle(INVALID_HANDLE),
      m_symbol(""),
      m_timeframe(PERIOD_CURRENT),
      m_logger(NULL)
   {}

   void SetLogger(CLogger *logger) { m_logger = logger; }

   bool Init(const string symbol, const ENUM_TIMEFRAMES timeframe,
             const int fastEma, const int slowEma,
             const int adxPeriod, const int rsiPeriod, const int atrPeriod)
   {
      m_symbol    = symbol;
      m_timeframe = timeframe;

      m_fastEmaHandle = iMA(m_symbol, m_timeframe, fastEma, 0, MODE_EMA, PRICE_CLOSE);
      m_slowEmaHandle = iMA(m_symbol, m_timeframe, slowEma, 0, MODE_EMA, PRICE_CLOSE);
      m_adxHandle     = iADX(m_symbol, m_timeframe, adxPeriod);
      m_rsiHandle     = iRSI(m_symbol, m_timeframe, rsiPeriod, PRICE_CLOSE);
      m_atrHandle     = iATR(m_symbol, m_timeframe, atrPeriod);

      if(m_fastEmaHandle == INVALID_HANDLE ||
         m_slowEmaHandle == INVALID_HANDLE ||
         m_adxHandle     == INVALID_HANDLE ||
         m_rsiHandle     == INVALID_HANDLE ||
         m_atrHandle     == INVALID_HANDLE)
      {
         if(m_logger != NULL)
            m_logger.Error("Failed to create one or more indicator handles.");
         return false;
      }

      if(m_logger != NULL)
         m_logger.Info("Indicators initialized successfully.");

      return true;
   }

   void Deinit(void)
   {
      if(m_fastEmaHandle != INVALID_HANDLE) IndicatorRelease(m_fastEmaHandle);
      if(m_slowEmaHandle != INVALID_HANDLE) IndicatorRelease(m_slowEmaHandle);
      if(m_adxHandle     != INVALID_HANDLE) IndicatorRelease(m_adxHandle);
      if(m_rsiHandle     != INVALID_HANDLE) IndicatorRelease(m_rsiHandle);
      if(m_atrHandle     != INVALID_HANDLE) IndicatorRelease(m_atrHandle);

      m_fastEmaHandle = INVALID_HANDLE;
      m_slowEmaHandle = INVALID_HANDLE;
      m_adxHandle     = INVALID_HANDLE;
      m_rsiHandle     = INVALID_HANDLE;
      m_atrHandle     = INVALID_HANDLE;
   }

   // Closed-bar values only (shift = 1) to avoid repainting
   bool GetFastEMA(double &value) const   { return CopyValue(m_fastEmaHandle, 0, 1, value); }
   bool GetSlowEMA(double &value) const   { return CopyValue(m_slowEmaHandle, 0, 1, value); }
   bool GetADX(double &value) const       { return CopyValue(m_adxHandle, 0, 1, value); }
   bool GetRSI(double &value) const       { return CopyValue(m_rsiHandle, 0, 1, value); }
   bool GetATR(double &value) const       { return CopyValue(m_atrHandle, 0, 1, value); }
};

//+------------------------------------------------------------------+
//| CSignalAnalyzer - Combines EMA, ADX, and RSI filters              |
//+------------------------------------------------------------------+
class CSignalAnalyzer
{
private:
   CIndicatorManager *m_indicators;
   CLogger           *m_logger;
   double             m_adxMin;
   double             m_rsiBuyLevel;
   double             m_rsiSellLevel;

public:
   CSignalAnalyzer(void) :
      m_indicators(NULL),
      m_logger(NULL),
      m_adxMin(25.0),
      m_rsiBuyLevel(50.0),
      m_rsiSellLevel(50.0)
   {}

   void Init(CIndicatorManager *indicators, CLogger *logger,
             const double adxMin, const double rsiBuyLevel, const double rsiSellLevel)
   {
      m_indicators   = indicators;
      m_logger       = logger;
      m_adxMin       = adxMin;
      m_rsiBuyLevel  = rsiBuyLevel;
      m_rsiSellLevel = rsiSellLevel;
   }

   ENUM_SIGNAL GetSignal(void) const
   {
      if(m_indicators == NULL)
         return SIGNAL_NONE;

      double fastEma = 0.0;
      double slowEma = 0.0;
      double adx     = 0.0;
      double rsi     = 0.0;

      if(!m_indicators.GetFastEMA(fastEma) ||
         !m_indicators.GetSlowEMA(slowEma) ||
         !m_indicators.GetADX(adx) ||
         !m_indicators.GetRSI(rsi))
      {
         if(m_logger != NULL)
            m_logger.Debug("Signal skipped: indicator data unavailable.");
         return SIGNAL_NONE;
      }

      // ADX must confirm trend strength on closed bar
      if(adx <= m_adxMin)
      {
         if(m_logger != NULL)
            m_logger.Debug(StringFormat("ADX filter failed: %.2f <= %.2f", adx, m_adxMin));
         return SIGNAL_NONE;
      }

      // BUY: uptrend + RSI confirmation
      if(fastEma > slowEma && rsi >= m_rsiBuyLevel)
      {
         if(m_logger != NULL)
            m_logger.Info(StringFormat("BUY signal | EMA50=%.5f EMA200=%.5f ADX=%.2f RSI=%.2f",
                                       fastEma, slowEma, adx, rsi));
         return SIGNAL_BUY;
      }

      // SELL: downtrend + RSI confirmation
      if(fastEma < slowEma && rsi <= m_rsiSellLevel)
      {
         if(m_logger != NULL)
            m_logger.Info(StringFormat("SELL signal | EMA50=%.5f EMA200=%.5f ADX=%.2f RSI=%.2f",
                                       fastEma, slowEma, adx, rsi));
         return SIGNAL_SELL;
      }

      if(m_logger != NULL)
         m_logger.Debug(StringFormat("No signal | EMA50=%.5f EMA200=%.5f ADX=%.2f RSI=%.2f",
                                     fastEma, slowEma, adx, rsi));
      return SIGNAL_NONE;
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
   CLogger            m_logger;
   CIndicatorManager  m_indicators;
   CSignalAnalyzer    m_signals;
   CRiskManager       m_risk;
   CFilterManager     m_filters;
   CPositionManager   m_positions;
   CTradeExecutor     m_executor;

   string             m_symbol;
   ENUM_TIMEFRAMES    m_timeframe;
   datetime           m_lastBarTime;
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
      if(InpADXPeriod <= 0 || InpRSIPeriod <= 0 || InpATRPeriod <= 0)
      {
         m_logger.Error("Indicator periods must be greater than zero.");
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
      m_slMultiplier(2.0),
      m_tpMultiplier(3.0)
   {}

   bool Init(void)
   {
      m_symbol    = _Symbol;
      m_timeframe = PERIOD_CURRENT;
      m_lastBarTime = iTime(m_symbol, m_timeframe, 0);
      m_slMultiplier = InpSL_ATR_Multiplier;
      m_tpMultiplier = InpTP_ATR_Multiplier;

      m_logger.Init(InpLogLevel, "ProEA");
      m_logger.Info("Initializing Expert Advisor...");

      if(!ValidateInputs())
         return false;

      m_indicators.SetLogger(GetPointer(m_logger));
      if(!m_indicators.Init(m_symbol, m_timeframe,
                            InpFastEMA, InpSlowEMA,
                            InpADXPeriod, InpRSIPeriod, InpATRPeriod))
         return false;

      m_signals.Init(GetPointer(m_indicators), GetPointer(m_logger),
                     InpADXMinLevel, InpRSIBuyLevel, InpRSISellLevel);

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

      m_logger.Info(StringFormat("EA ready | Symbol=%s Magic=%I64u", m_symbol, InpMagicNumber));
      return true;
   }

   void Deinit(void)
   {
      m_indicators.Deinit();
      m_logger.Info("Expert Advisor deinitialized.");
   }

   void OnTick(void)
   {
      // Always manage open positions (trailing / break-even)
      double atrValue = 0.0;
      if(m_indicators.GetATR(atrValue))
         m_positions.ManageOpenPosition(atrValue);

      // Entry logic only on new closed candle
      if(!IsNewBar())
         return;

      m_logger.Debug("New bar detected - evaluating entry conditions.");

      // One trade per symbol - no duplicates, no hedging
      if(m_positions.HasOpenPosition())
      {
         m_logger.Debug("Entry skipped: position already open for this symbol.");
         return;
      }

      if(!m_filters.PassAllFilters())
         return;

      const ENUM_SIGNAL signal = m_signals.GetSignal();
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
