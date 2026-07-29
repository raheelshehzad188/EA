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
//| EA version and shared constants                                   |
//+------------------------------------------------------------------+
#define EA_PRODUCT_NAME           "ProEA"
#define EA_VERSION_STRING         "1.0"
#define EA_TRADE_DEVIATION_POINTS  20

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
input string         InpTradeComment       = "ProEA_v1";   // Legacy label (trade tag uses EA version)

input group "=== Trend Filter (EMA) ==="
input int            InpFastEMA            = 50;           // Fast EMA period
input int            InpSlowEMA            = 200;          // Slow EMA period

input group "=== RSI Momentum ==="
input int            InpRSIPeriod          = 14;           // RSI period
input double         InpRSIBuyMin          = 55.0;         // BUY: RSI minimum (rising)
input double         InpRSISellMax         = 45.0;         // SELL: RSI maximum (falling)
input double         InpRSICrossLevel      = 50.0;         // Exit: RSI reversal level

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
input int            InpConfirmWindowBars  = 3;            // Confirm within N bars after EMA touch

input group "=== ATR Volatility Filter ==="
input int            InpATRAvgPeriod       = 20;           // ATR average period
input double         InpATRMinRatio        = 0.70;         // Min ATR vs average (avoid dead markets)
input double         InpATRMaxRatio        = 3.00;         // Max ATR vs average (avoid news spikes)

input group "=== Dynamic ADX ==="
input bool           InpUseDynamicADX      = true;         // Enable dynamic ADX threshold
input int            InpADXAvgPeriod       = 14;           // ADX average period
input bool           InpRequireADXRising   = true;         // Require ADX rising on closed bar

input group "=== Range Avoidance (Adaptive) ==="
// EMA separation threshold scales with ADX: >35 → 0.20, >25 → 0.25, else → 0.30 ATR

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
input bool           InpEnableDiagnostics  = true;         // Per-bar signal pipeline report
input bool           InpEnablePipelineLog    = true;         // [PASS/FAIL] entry pipeline instrumentation
input bool           InpEnableStrategyAudit  = false;        // Strategy audit mode (per-trade detail log)

//+------------------------------------------------------------------+
//| SSettings - Central configuration snapshot                        |
//+------------------------------------------------------------------+
struct SSettings
{
   ulong             magicNumber;
   string            tradeComment;
   int               fastEma;
   int               slowEma;
   int               rsiPeriod;
   double            rsiBuyMin;
   double            rsiSellMax;
   double            rsiCrossLevel;
   ENUM_TIMEFRAMES   htfTimeframe;
   int               htfFastEma;
   int               htfSlowEma;
   int               swingLookback;
   int               swingStrength;
   int               pullbackMaxBars;
   double            pullbackAtrZone;
   int               confirmWindowBars;
   int               atrAvgPeriod;
   double            atrMinRatio;
   double            atrMaxRatio;
   bool              useDynamicAdx;
   int               adxAvgPeriod;
   bool              requireAdxRising;
   bool              useCandleConfirm;
   bool              useStructureExit;
   bool              useRsiExit;
   bool              useOppositeBosExit;
   int               adxPeriod;
   double            adxMinLevel;
   int               atrPeriod;
   double            slAtrMultiplier;
   double            tpAtrMultiplier;
   ENUM_LOT_MODE     lotMode;
   double            fixedLot;
   double            riskPercent;
   int               maxSpreadPoints;
   bool              useSessionFilter;
   int               sessionStartHour;
   int               sessionStartMinute;
   int               sessionEndHour;
   int               sessionEndMinute;
   bool              useTrailingStop;
   double            trailStartAtr;
   double            trailStepAtr;
   bool              useBreakEven;
   double            breakEvenTriggerAtr;
   int               breakEvenOffsetPoints;
   ENUM_LOG_LEVEL    logLevel;
   bool              enableDiagnostics;
   bool              enablePipelineLog;
   bool              enableStrategyAudit;
   double            rangeAdxTier1;
   double            rangeAdxTier2;
   double            rangeEmaSepTier1;
   double            rangeEmaSepTier2;
   double            rangeEmaSepTier3;
};

//+------------------------------------------------------------------+
//| CLogger - Centralized logging                                     |
//+------------------------------------------------------------------+
class CLogger
{
private:
   ENUM_LOG_LEVEL m_level;
   string         m_prefix;

public:
   CLogger(void) : m_level(LOG_LEVEL_INFO), m_prefix(EA_PRODUCT_NAME) {}

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

   void Diag(const string message) const
   {
      Print(m_prefix, " [DIAG]  ", message);
   }

   void Pipe(const string message) const
   {
      Print(m_prefix, " [PIPE]  ", message);
   }

   void Audit(const string message) const
   {
      Print(m_prefix, " [AUDIT] ", message);
   }
};

//+------------------------------------------------------------------+
//| CSettingsManager - Load, validate, and expose configuration       |
//+------------------------------------------------------------------+
class CSettingsManager
{
private:
   SSettings m_settings;

   string TimeframeLabel(const ENUM_TIMEFRAMES timeframe) const
   {
      switch(timeframe)
      {
         case PERIOD_M1:   return "M1";
         case PERIOD_M5:   return "M5";
         case PERIOD_M15:  return "M15";
         case PERIOD_M30:  return "M30";
         case PERIOD_H1:   return "H1";
         case PERIOD_H4:   return "H4";
         case PERIOD_D1:   return "D1";
         case PERIOD_W1:   return "W1";
         case PERIOD_MN1:  return "MN1";
         default:          return EnumToString(timeframe);
      }
   }

   string LotModeLabel(const ENUM_LOT_MODE mode) const
   {
      return (mode == LOT_MODE_FIXED ? "Fixed" : "Risk Percent");
   }

   string SessionLabel(void) const
   {
      if(!m_settings.useSessionFilter)
         return "Disabled";

      return StringFormat("%02d:%02d - %02d:%02d",
                          m_settings.sessionStartHour, m_settings.sessionStartMinute,
                          m_settings.sessionEndHour, m_settings.sessionEndMinute);
   }

public:
   CSettingsManager(void) {}

   void LoadFromInputs(void)
   {
      m_settings.magicNumber            = InpMagicNumber;
      m_settings.tradeComment           = StringFormat("%s v%s", EA_PRODUCT_NAME, EA_VERSION_STRING);
      m_settings.fastEma                = InpFastEMA;
      m_settings.slowEma                = InpSlowEMA;
      m_settings.rsiPeriod              = InpRSIPeriod;
      m_settings.rsiBuyMin              = InpRSIBuyMin;
      m_settings.rsiSellMax             = InpRSISellMax;
      m_settings.rsiCrossLevel          = InpRSICrossLevel;
      m_settings.htfTimeframe           = InpHTFTimeframe;
      m_settings.htfFastEma             = InpHTFFastEMA;
      m_settings.htfSlowEma             = InpHTFSlowEMA;
      m_settings.swingLookback          = InpSwingLookback;
      m_settings.swingStrength          = InpSwingStrength;
      m_settings.pullbackMaxBars        = InpPullbackMaxBars;
      m_settings.pullbackAtrZone        = InpPullbackATRZone;
      m_settings.confirmWindowBars      = InpConfirmWindowBars;
      m_settings.atrAvgPeriod           = InpATRAvgPeriod;
      m_settings.atrMinRatio            = InpATRMinRatio;
      m_settings.atrMaxRatio            = InpATRMaxRatio;
      m_settings.useDynamicAdx          = InpUseDynamicADX;
      m_settings.adxAvgPeriod           = InpADXAvgPeriod;
      m_settings.requireAdxRising       = InpRequireADXRising;
      m_settings.useCandleConfirm       = InpUseCandleConfirm;
      m_settings.useStructureExit       = InpUseStructureExit;
      m_settings.useRsiExit             = InpUseRSIExit;
      m_settings.useOppositeBosExit     = InpUseOppositeBOSExit;
      m_settings.adxPeriod              = InpADXPeriod;
      m_settings.adxMinLevel            = InpADXMinLevel;
      m_settings.atrPeriod              = InpATRPeriod;
      m_settings.slAtrMultiplier        = InpSL_ATR_Multiplier;
      m_settings.tpAtrMultiplier        = InpTP_ATR_Multiplier;
      m_settings.lotMode                = InpLotMode;
      m_settings.fixedLot               = InpFixedLot;
      m_settings.riskPercent            = InpRiskPercent;
      m_settings.maxSpreadPoints        = InpMaxSpreadPoints;
      m_settings.useSessionFilter       = InpUseSessionFilter;
      m_settings.sessionStartHour       = InpSessionStartHour;
      m_settings.sessionStartMinute     = InpSessionStartMinute;
      m_settings.sessionEndHour         = InpSessionEndHour;
      m_settings.sessionEndMinute       = InpSessionEndMinute;
      m_settings.useTrailingStop        = InpUseTrailingStop;
      m_settings.trailStartAtr          = InpTrailStartATR;
      m_settings.trailStepAtr           = InpTrailStepATR;
      m_settings.useBreakEven           = InpUseBreakEven;
      m_settings.breakEvenTriggerAtr    = InpBreakEvenTriggerATR;
      m_settings.breakEvenOffsetPoints  = InpBreakEvenOffsetPoints;
      m_settings.logLevel               = InpLogLevel;
      m_settings.enableDiagnostics      = InpEnableDiagnostics;
      m_settings.enablePipelineLog      = InpEnablePipelineLog;
      m_settings.enableStrategyAudit    = InpEnableStrategyAudit;
      m_settings.rangeAdxTier1          = 35.0;
      m_settings.rangeAdxTier2          = 25.0;
      m_settings.rangeEmaSepTier1       = 0.20;
      m_settings.rangeEmaSepTier2       = 0.25;
      m_settings.rangeEmaSepTier3       = 0.30;
   }

   bool Validate(string &errorMessage) const
   {
      errorMessage = "";

      if(m_settings.fastEma <= 0 || m_settings.slowEma <= 0 || m_settings.fastEma >= m_settings.slowEma)
      {
         errorMessage = "Invalid EMA periods: Fast EMA must be less than Slow EMA.";
         return false;
      }
      if(m_settings.htfFastEma <= 0 || m_settings.htfSlowEma <= 0 ||
         m_settings.htfFastEma >= m_settings.htfSlowEma)
      {
         errorMessage = "Invalid HTF EMA periods: Fast EMA must be less than Slow EMA.";
         return false;
      }
      if(m_settings.adxPeriod <= 0 || m_settings.rsiPeriod <= 0 || m_settings.atrPeriod <= 0)
      {
         errorMessage = "Indicator periods must be greater than zero.";
         return false;
      }
      if(m_settings.swingStrength <= 0 || m_settings.swingLookback <= m_settings.swingStrength * 2)
      {
         errorMessage = "Invalid swing parameters.";
         return false;
      }
      if(m_settings.pullbackMaxBars <= 0)
      {
         errorMessage = "Pullback max bars must be greater than zero.";
         return false;
      }
      if(m_settings.confirmWindowBars <= 0)
      {
         errorMessage = "Confirmation window bars must be greater than zero.";
         return false;
      }
      if(m_settings.rsiBuyMin <= 0.0 || m_settings.rsiSellMax <= 0.0 ||
         m_settings.rsiBuyMin <= m_settings.rsiSellMax)
      {
         errorMessage = "Invalid RSI momentum levels: BuyMin must be greater than SellMax.";
         return false;
      }
      if(m_settings.atrAvgPeriod <= 0 || m_settings.adxAvgPeriod <= 0)
      {
         errorMessage = "Average periods must be greater than zero.";
         return false;
      }
      if(m_settings.atrMinRatio <= 0.0 || m_settings.atrMaxRatio <= m_settings.atrMinRatio)
      {
         errorMessage = "Invalid ATR ratio parameters.";
         return false;
      }
      if(m_settings.slAtrMultiplier <= 0.0 || m_settings.tpAtrMultiplier <= 0.0)
      {
         errorMessage = "ATR multipliers must be greater than zero.";
         return false;
      }
      if(m_settings.fixedLot <= 0.0 && m_settings.lotMode == LOT_MODE_FIXED)
      {
         errorMessage = "Fixed lot must be greater than zero.";
         return false;
      }
      if(m_settings.riskPercent <= 0.0 && m_settings.lotMode == LOT_MODE_RISK_PERCENT)
      {
         errorMessage = "Risk percent must be greater than zero.";
         return false;
      }
      if(m_settings.maxSpreadPoints <= 0)
      {
         errorMessage = "Maximum spread must be greater than zero.";
         return false;
      }
      if(m_settings.sessionStartHour < 0 || m_settings.sessionStartHour > 23 ||
         m_settings.sessionEndHour < 0 || m_settings.sessionEndHour > 23 ||
         m_settings.sessionStartMinute < 0 || m_settings.sessionStartMinute > 59 ||
         m_settings.sessionEndMinute < 0 || m_settings.sessionEndMinute > 59)
      {
         errorMessage = "Session hours/minutes must be within valid clock ranges.";
         return false;
      }
      if(m_settings.useTrailingStop &&
         (m_settings.trailStartAtr <= 0.0 || m_settings.trailStepAtr <= 0.0))
      {
         errorMessage = "Trailing stop ATR multipliers must be greater than zero.";
         return false;
      }
      if(m_settings.useBreakEven && m_settings.breakEvenTriggerAtr <= 0.0)
      {
         errorMessage = "Break-even trigger ATR must be greater than zero.";
         return false;
      }
      return true;
   }

   SSettings GetCopy(void) const
   {
      SSettings copy;
      copy = m_settings;
      return copy;
   }

   bool EnablePipelineLog(void) const { return m_settings.enablePipelineLog; }
   bool EnableDiagnostics(void) const { return m_settings.enableDiagnostics; }
   bool EnableStrategyAudit(void) const { return m_settings.enableStrategyAudit; }
   double SlAtrMultiplier(void) const { return m_settings.slAtrMultiplier; }

   void PrintStartupConfig(CLogger *logger, const string symbol,
                           const ENUM_TIMEFRAMES timeframe) const
   {
      if(logger == NULL)
         return;

      logger.Info("==========================");
      logger.Info("EA STARTUP CONFIGURATION");
      logger.Info("==========================");
      logger.Info(StringFormat("EA Version:  %s v%s", EA_PRODUCT_NAME, EA_VERSION_STRING));
      logger.Info(StringFormat("Symbol:      %s", symbol));
      logger.Info(StringFormat("Timeframe:   %s", TimeframeLabel(timeframe)));
      logger.Info(StringFormat("Risk:        %s (%.2f%% / %.2f lot)",
                               LotModeLabel(m_settings.lotMode),
                               m_settings.riskPercent,
                               m_settings.fixedLot));
      logger.Info(StringFormat("ATR Min:     %.2f", m_settings.atrMinRatio));
      logger.Info(StringFormat("ATR Max:     %.2f", m_settings.atrMaxRatio));
      logger.Info(StringFormat("ADX:         %.1f", m_settings.adxMinLevel));
      logger.Info(StringFormat("EMA:         %d / %d", m_settings.fastEma, m_settings.slowEma));
      logger.Info(StringFormat("Session:     %s", SessionLabel()));
      logger.Info(StringFormat("Magic:       %I64u", m_settings.magicNumber));
      logger.Info(StringFormat("Trade Tag:   %s", m_settings.tradeComment));
      logger.Info("==========================");
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
             const SSettings &settings)
   {
      return Init(symbol, timeframe,
                  settings.fastEma, settings.slowEma,
                  settings.adxPeriod, settings.rsiPeriod, settings.atrPeriod,
                  settings.htfTimeframe, settings.htfFastEma, settings.htfSlowEma);
   }

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
             CLogger *logger, const SSettings &settings)
   {
      Init(symbol, timeframe, settings.swingLookback, settings.swingStrength, logger);
   }

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
   double           m_rsiBuyMin;
   double           m_rsiSellMax;
   int              m_confirmWindowBars;
   bool             m_useCandleConfirm;
   bool             m_zoneTouched;
   int              m_confirmBarsRemaining;
   bool             m_rsiConfirmed;
   bool             m_candleConfirmed;
   CLogger         *m_logger;

   void ResetConfirmState(void)
   {
      m_zoneTouched           = false;
      m_confirmBarsRemaining  = 0;
      m_rsiConfirmed          = false;
      m_candleConfirmed       = false;
   }

   bool IsZoneTouched(const ENUM_SIGNAL direction,
                      const CIndicatorManager *indicators) const
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
         return (low1 <= fastEma + zone);

      if(direction == SIGNAL_SELL)
         return (high1 >= fastEma - zone);

      return false;
   }

   bool IsRSIMomentum(const ENUM_SIGNAL direction,
                      const CIndicatorManager *indicators) const
   {
      double rsi1 = 0.0;
      double rsi2 = 0.0;

      if(!indicators.GetRSI(rsi1, 1) || !indicators.GetRSI(rsi2, 2))
         return false;

      if(direction == SIGNAL_BUY)
         return (rsi1 > m_rsiBuyMin && rsi1 > rsi2);

      if(direction == SIGNAL_SELL)
         return (rsi1 < m_rsiSellMax && rsi1 < rsi2);

      return false;
   }

   bool IsCandleConfirmed(const ENUM_SIGNAL direction,
                          const CIndicatorManager *indicators) const
   {
      if(!m_useCandleConfirm)
         return true;

      double open1 = 0.0, high1 = 0.0, low1 = 0.0, close1 = 0.0;
      double fastEma = 0.0;

      if(!indicators.GetBarOHLC(1, open1, high1, low1, close1) ||
         !indicators.GetFastEMA(fastEma, 1))
         return false;

      if(direction == SIGNAL_BUY)
         return (close1 > open1 && close1 > fastEma);

      if(direction == SIGNAL_SELL)
         return (close1 < open1 && close1 < fastEma);

      return false;
   }

   void UpdateConfirmFlags(const ENUM_SIGNAL direction,
                           const CIndicatorManager *indicators)
   {
      if(IsRSIMomentum(direction, indicators))
         m_rsiConfirmed = true;
      if(IsCandleConfirmed(direction, indicators))
         m_candleConfirmed = true;
   }

   bool IsFullyConfirmed(void) const
   {
      return (m_zoneTouched && m_rsiConfirmed && m_candleConfirmed);
   }

public:
   CPullbackEntryManager(void) :
      m_state(SETUP_NONE),
      m_barsRemaining(0),
      m_maxBars(8),
      m_pullbackAtrZone(0.5),
      m_rsiBuyMin(55.0),
      m_rsiSellMax(45.0),
      m_confirmWindowBars(3),
      m_useCandleConfirm(true),
      m_zoneTouched(false),
      m_confirmBarsRemaining(0),
      m_rsiConfirmed(false),
      m_candleConfirmed(false),
      m_logger(NULL)
   {}

   void Init(CLogger *logger, const SSettings &settings)
   {
      m_logger            = logger;
      m_maxBars           = settings.pullbackMaxBars;
      m_pullbackAtrZone   = settings.pullbackAtrZone;
      m_rsiBuyMin         = settings.rsiBuyMin;
      m_rsiSellMax        = settings.rsiSellMax;
      m_confirmWindowBars = settings.confirmWindowBars;
      m_useCandleConfirm  = settings.useCandleConfirm;
      Reset();
   }

   void Reset(void)
   {
      m_state         = SETUP_NONE;
      m_barsRemaining = 0;
      ResetConfirmState();
   }

   ENUM_SETUP_STATE GetState(void) const { return m_state; }
   int              GetBarsRemaining(void) const { return m_barsRemaining; }

   bool CheckPullback(const ENUM_SIGNAL direction,
                      const CIndicatorManager *indicators) const
   {
      return (m_zoneTouched || IsZoneTouched(direction, indicators));
   }

   bool CheckRSIMomentum(const ENUM_SIGNAL direction,
                         const CIndicatorManager *indicators) const
   {
      return (m_rsiConfirmed || IsRSIMomentum(direction, indicators));
   }

   bool CheckCandleConfirm(const ENUM_SIGNAL direction,
                           const CIndicatorManager *indicators) const
   {
      return (m_candleConfirmed || IsCandleConfirmed(direction, indicators));
   }

   void LogPullbackDetail(const ENUM_SIGNAL direction,
                          const CIndicatorManager *indicators) const
   {
      if(m_logger == NULL || indicators == NULL)
         return;

      double fastEma = 0.0;
      double atr     = 0.0;
      double low1 = 0.0, high1 = 0.0, open1 = 0.0, close1 = 0.0;

      if(!indicators.GetFastEMA(fastEma, 1) ||
         !indicators.GetATR(atr, 1) ||
         !indicators.GetBarOHLC(1, open1, high1, low1, close1))
      {
         m_logger.Diag("Pullback detail: indicator/OHLC data unavailable.");
         return;
      }

      const double zone = m_pullbackAtrZone * atr;

      if(direction == SIGNAL_BUY)
      {
         const bool touchedZone = (low1 <= fastEma + zone);
         m_logger.Diag(StringFormat("Pullback BUY detail | Low=%.5f EMA=%.5f ZoneTop=%.5f | touched=%s window=%d",
                                    low1, fastEma, fastEma + zone,
                                    (touchedZone ? "TRUE" : "FALSE"), m_confirmBarsRemaining));
      }
      else if(direction == SIGNAL_SELL)
      {
         const bool touchedZone = (high1 >= fastEma - zone);
         m_logger.Diag(StringFormat("Pullback SELL detail | High=%.5f EMA=%.5f ZoneBot=%.5f | touched=%s window=%d",
                                    high1, fastEma, fastEma - zone,
                                    (touchedZone ? "TRUE" : "FALSE"), m_confirmBarsRemaining));
      }
   }

   void LogRSIDetail(const ENUM_SIGNAL direction,
                     const CIndicatorManager *indicators) const
   {
      if(m_logger == NULL || indicators == NULL)
         return;

      double rsi1 = 0.0;
      double rsi2 = 0.0;
      if(!indicators.GetRSI(rsi1, 1) || !indicators.GetRSI(rsi2, 2))
      {
         m_logger.Diag("RSI detail: data unavailable.");
         return;
      }

      if(direction == SIGNAL_BUY)
      {
         const bool momentum = (rsi1 > m_rsiBuyMin && rsi1 > rsi2);
         m_logger.Diag(StringFormat("RSI BUY detail | RSI[1]=%.2f RSI[2]=%.2f Min=%.2f | momentum=%s rising=%s",
                                    rsi1, rsi2, m_rsiBuyMin,
                                    (momentum ? "TRUE" : "FALSE"),
                                    (rsi1 > rsi2 ? "TRUE" : "FALSE")));
      }
      else if(direction == SIGNAL_SELL)
      {
         const bool momentum = (rsi1 < m_rsiSellMax && rsi1 < rsi2);
         m_logger.Diag(StringFormat("RSI SELL detail | RSI[1]=%.2f RSI[2]=%.2f Max=%.2f | momentum=%s falling=%s",
                                    rsi1, rsi2, m_rsiSellMax,
                                    (momentum ? "TRUE" : "FALSE"),
                                    (rsi1 < rsi2 ? "TRUE" : "FALSE")));
      }
   }

   void LogCandleDetail(const ENUM_SIGNAL direction,
                        const CIndicatorManager *indicators) const
   {
      if(m_logger == NULL || indicators == NULL)
         return;

      if(!m_useCandleConfirm)
      {
         m_logger.Diag("Candle detail: confirmation disabled by input.");
         return;
      }

      double open1 = 0.0, high1 = 0.0, low1 = 0.0, close1 = 0.0;
      double fastEma = 0.0;

      if(!indicators.GetBarOHLC(1, open1, high1, low1, close1) ||
         !indicators.GetFastEMA(fastEma, 1))
      {
         m_logger.Diag("Candle detail: OHLC data unavailable.");
         return;
      }

      if(direction == SIGNAL_BUY)
      {
         const bool bullishBody = (close1 > open1);
         const bool aboveEma    = (close1 > fastEma);
         m_logger.Diag(StringFormat("Candle BUY detail | O=%.5f C=%.5f EMA50=%.5f | bullish=%s aboveEMA=%s",
                                    open1, close1, fastEma,
                                    (bullishBody ? "TRUE" : "FALSE"),
                                    (aboveEma ? "TRUE" : "FALSE")));
      }
      else if(direction == SIGNAL_SELL)
      {
         const bool bearishBody = (close1 < open1);
         const bool belowEma    = (close1 < fastEma);
         m_logger.Diag(StringFormat("Candle SELL detail | O=%.5f C=%.5f EMA50=%.5f | bearish=%s belowEMA=%s",
                                    open1, close1, fastEma,
                                    (bearishBody ? "TRUE" : "FALSE"),
                                    (belowEma ? "TRUE" : "FALSE")));
      }
   }

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
      ResetConfirmState();

      if(m_logger != NULL)
         m_logger.Info(StringFormat("Pullback armed | Direction=%s | MaxBars=%d | ConfirmWindow=%d",
                                    (direction == SIGNAL_BUY ? "BUY" : "SELL"),
                                    m_maxBars, m_confirmWindowBars));
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

   ENUM_SIGNAL TryConfirmEntry(const CIndicatorManager *indicators)
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

      if(!m_zoneTouched)
      {
         if(!IsZoneTouched(direction, indicators))
         {
            if(m_logger != NULL)
               m_logger.Debug("Pullback zone not yet touched.");
            return SIGNAL_NONE;
         }

         m_zoneTouched          = true;
         m_confirmBarsRemaining = m_confirmWindowBars;
         UpdateConfirmFlags(direction, indicators);

         if(IsFullyConfirmed())
         {
            if(m_logger != NULL)
               m_logger.Info(StringFormat("Pullback entry confirmed | Direction=%s (same bar as touch)",
                                          (direction == SIGNAL_BUY ? "BUY" : "SELL")));
            Reset();
            return direction;
         }

         return SIGNAL_NONE;
      }

      UpdateConfirmFlags(direction, indicators);

      if(IsFullyConfirmed())
      {
         if(m_logger != NULL)
            m_logger.Info(StringFormat("Pullback entry confirmed | Direction=%s",
                                       (direction == SIGNAL_BUY ? "BUY" : "SELL")));
         Reset();
         return direction;
      }

      m_confirmBarsRemaining--;
      if(m_confirmBarsRemaining <= 0)
      {
         if(m_logger != NULL)
            m_logger.Debug("Confirmation window expired - waiting for new EMA zone touch.");
         ResetConfirmState();
      }

      return SIGNAL_NONE;
   }
};

//+------------------------------------------------------------------+
//| CSignalEngine - Multi-filter signal generation (non-repainting)   |
//+------------------------------------------------------------------+
class CSignalEngine
{
private:
   const CIndicatorManager  *m_indicators;
   CMarketStructure   *m_structure;
   CLogger            *m_logger;
   double              m_adxMin;
   bool                m_useDynamicAdx;
   int                 m_adxAvgPeriod;
   bool                m_requireAdxRising;
   int                 m_atrAvgPeriod;
   double              m_atrMinRatio;
   double              m_atrMaxRatio;
   double              m_rangeAdxTier1;
   double              m_rangeAdxTier2;
   double              m_rangeEmaSepTier1;
   double              m_rangeEmaSepTier2;
   double              m_rangeEmaSepTier3;

   double GetAdaptiveEmaSepThreshold(const double adx) const
   {
      if(adx > m_rangeAdxTier1)
         return m_rangeEmaSepTier1;
      if(adx > m_rangeAdxTier2)
         return m_rangeEmaSepTier2;
      return m_rangeEmaSepTier3;
   }

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
      const double minSep = GetAdaptiveEmaSepThreshold(adx1);
      if(emaSep < minSep)
      {
         if(m_logger != NULL)
            m_logger.Debug(StringFormat("Range filter | EMA sep/ATR=%.2f < %.2f (ADX=%.2f)",
                                        emaSep, minSep, adx1));
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
      m_adxMin(0.0),
      m_useDynamicAdx(false),
      m_adxAvgPeriod(0),
      m_requireAdxRising(false),
      m_atrAvgPeriod(0),
      m_atrMinRatio(0.0),
      m_atrMaxRatio(0.0),
      m_rangeAdxTier1(0.0),
      m_rangeAdxTier2(0.0),
      m_rangeEmaSepTier1(0.0),
      m_rangeEmaSepTier2(0.0),
      m_rangeEmaSepTier3(0.0)
   {}

   void Init(const CIndicatorManager *indicators, CMarketStructure *structure, CLogger *logger,
             const SSettings &settings)
   {
      m_indicators         = indicators;
      m_structure          = structure;
      m_logger             = logger;
      m_adxMin             = settings.adxMinLevel;
      m_useDynamicAdx      = settings.useDynamicAdx;
      m_adxAvgPeriod       = settings.adxAvgPeriod;
      m_requireAdxRising   = settings.requireAdxRising;
      m_atrAvgPeriod       = settings.atrAvgPeriod;
      m_atrMinRatio        = settings.atrMinRatio;
      m_atrMaxRatio        = settings.atrMaxRatio;
      m_rangeAdxTier1      = settings.rangeAdxTier1;
      m_rangeAdxTier2      = settings.rangeAdxTier2;
      m_rangeEmaSepTier1   = settings.rangeEmaSepTier1;
      m_rangeEmaSepTier2   = settings.rangeEmaSepTier2;
      m_rangeEmaSepTier3   = settings.rangeEmaSepTier3;
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

   // --- Diagnostic accessors (read-only, no strategy change) ---
   bool DiagBOS(const ENUM_SIGNAL direction) const
   {
      if(m_structure == NULL)
         return false;
      if(direction == SIGNAL_BUY)
         return m_structure.IsBullishBOS();
      if(direction == SIGNAL_SELL)
         return m_structure.IsBearishBOS();
      return false;
   }

   bool DiagHTFTrend(const ENUM_SIGNAL direction) const
   {
      if(direction == SIGNAL_BUY)
         return IsHTFBullish();
      if(direction == SIGNAL_SELL)
         return IsHTFBearish();
      return false;
   }

   bool DiagLTFTrend(const ENUM_SIGNAL direction) const
   {
      return PassesLTFTrend(direction);
   }

   bool DiagADXFilter(void) const
   {
      double adx = 0.0;
      return PassesDynamicADX(adx);
   }

   bool DiagATRFilter(void) const
   {
      return PassesATRVolatilityFilter();
   }

   bool DiagRangeFilter(void) const
   {
      return !IsRangingMarket();
   }

   bool DiagCoreFilters(void) const
   {
      return PassesCoreFilters();
   }

   bool DiagValidateArmed(const ENUM_SIGNAL direction) const
   {
      return ValidateArmedSetup(direction);
   }

   void LogADXDetail(void) const
   {
      if(m_logger == NULL || m_indicators == NULL)
         return;

      double adx1 = 0.0;
      double adx2 = 0.0;
      double adxAvg = 0.0;

      if(!m_indicators.GetADX(adx1, 1) || !m_indicators.GetADX(adx2, 2))
      {
         m_logger.Diag("ADX detail: data unavailable.");
         return;
      }

      double threshold = m_adxMin;
      if(m_useDynamicAdx)
      {
         if(m_indicators.GetADXAverage(m_adxAvgPeriod, adxAvg))
            threshold = MathMax(m_adxMin, adxAvg * 0.90);
      }

      m_logger.Diag(StringFormat("ADX detail | ADX[1]=%.2f ADX[2]=%.2f Threshold=%.2f Avg=%.2f | above=%s rising=%s",
                                 adx1, adx2, threshold, adxAvg,
                                 (adx1 >= threshold ? "TRUE" : "FALSE"),
                                 ((!m_requireAdxRising || adx1 > adx2) ? "TRUE" : "FALSE")));
   }

   void LogATRDetail(void) const
   {
      if(m_logger == NULL || m_indicators == NULL)
         return;

      double atr1 = 0.0;
      double atrAvg = 0.0;
      if(!m_indicators.GetATR(atr1, 1) || !m_indicators.GetATRAverage(m_atrAvgPeriod, atrAvg))
      {
         m_logger.Diag("ATR detail: data unavailable.");
         return;
      }

      m_logger.Diag(StringFormat("ATR detail | ATR[1]=%.5f Avg=%.5f Min=%.5f Max=%.5f | inRange=%s",
                                 atr1, atrAvg,
                                 atrAvg * m_atrMinRatio, atrAvg * m_atrMaxRatio,
                                 (DiagATRFilter() ? "TRUE" : "FALSE")));
   }

   void LogRangeDetail(void) const
   {
      if(m_logger == NULL || m_indicators == NULL)
         return;

      double fastEma = 0.0;
      double slowEma = 0.0;
      double atr     = 0.0;
      double adx1    = 0.0;

      if(!m_indicators.GetFastEMA(fastEma, 1) ||
         !m_indicators.GetSlowEMA(slowEma, 1) ||
         !m_indicators.GetATR(atr, 1) ||
         !m_indicators.GetADX(adx1, 1))
      {
         m_logger.Diag("Range detail: data unavailable.");
         return;
      }

      const double emaSep = (atr > 0.0 ? MathAbs(fastEma - slowEma) / atr : 0.0);
      const double minSep = GetAdaptiveEmaSepThreshold(adx1);
      m_logger.Diag(StringFormat("Range detail | EMAsep/ATR=%.3f Min=%.3f ADX[1]=%.2f | trending=%s",
                                 emaSep, minSep, adx1,
                                 (DiagRangeFilter() ? "TRUE" : "FALSE")));
   }

   void LogLTFTrendDetail(const ENUM_SIGNAL direction) const
   {
      if(m_logger == NULL || m_indicators == NULL)
         return;

      double fastEma = 0.0;
      double slowEma = 0.0;
      double plusDi  = 0.0;
      double minusDi = 0.0;

      if(!m_indicators.GetFastEMA(fastEma, 1) ||
         !m_indicators.GetSlowEMA(slowEma, 1) ||
         !m_indicators.GetPlusDI(plusDi, 1) ||
         !m_indicators.GetMinusDI(minusDi, 1))
      {
         m_logger.Diag("LTF trend detail: data unavailable.");
         return;
      }

      m_logger.Diag(StringFormat("LTF detail | EMA50=%.5f EMA200=%.5f +DI=%.2f -DI=%.2f | dirOK=%s",
                                 fastEma, slowEma, plusDi, minusDi,
                                 (DiagLTFTrend(direction) ? "TRUE" : "FALSE")));
   }

   void LogHTFTrendDetail(const ENUM_SIGNAL direction) const
   {
      if(m_logger == NULL || m_indicators == NULL)
         return;

      double htfFast = 0.0;
      double htfSlow = 0.0;
      if(!m_indicators.GetHTFFastEMA(htfFast, 1) || !m_indicators.GetHTFSlowEMA(htfSlow, 1))
      {
         m_logger.Diag("HTF trend detail: data unavailable.");
         return;
      }

      m_logger.Diag(StringFormat("HTF detail | Fast=%.5f Slow=%.5f | dirOK=%s",
                                 htfFast, htfSlow,
                                 (DiagHTFTrend(direction) ? "TRUE" : "FALSE")));
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
   const CIndicatorManager *m_indicators;
   CMarketStructure *m_structure;
   CLogger          *m_logger;
   ulong             m_magic;
   double            m_rsiCrossLevel;
   bool              m_useStructureExit;
   bool              m_useRsiExit;
   bool              m_useOppositeBosExit;
   string            m_lastExitReason;

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
      m_useOppositeBosExit(true),
      m_lastExitReason("")
   {}

   void Init(CLogger *logger, const SSettings &settings,
             const CIndicatorManager *indicators,
             CMarketStructure *structure)
   {
      m_logger             = logger;
      m_magic              = settings.magicNumber;
      m_indicators         = indicators;
      m_structure          = structure;
      m_rsiCrossLevel      = settings.rsiCrossLevel;
      m_useStructureExit   = settings.useStructureExit;
      m_useRsiExit         = settings.useRsiExit;
      m_useOppositeBosExit = settings.useOppositeBosExit;

      m_trade.SetExpertMagicNumber(m_magic);
      m_trade.SetDeviationInPoints(EA_TRADE_DEVIATION_POINTS);
   }

   bool RefreshSymbol(const string symbol)
   {
      if(!m_symbol.Name(symbol))
         return false;
      m_trade.SetTypeFilling(GetFillingMode(symbol));
      return true;
   }

   string GetLastExitReason(void) const { return m_lastExitReason; }

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

      m_lastExitReason = reason;

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

   void Init(CLogger *logger, const SSettings &settings)
   {
      m_logger      = logger;
      m_lotMode     = settings.lotMode;
      m_fixedLot    = settings.fixedLot;
      m_riskPercent = settings.riskPercent;
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

   void Init(CLogger *logger, const SSettings &settings)
   {
      m_logger           = logger;
      m_maxSpreadPoints  = settings.maxSpreadPoints;
      m_useSession       = settings.useSessionFilter;
      m_startHour        = settings.sessionStartHour;
      m_startMinute      = settings.sessionStartMinute;
      m_endHour          = settings.sessionEndHour;
      m_endMinute        = settings.sessionEndMinute;
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
//| CSignalDiagnostics - Per-bar pipeline report                      |
//+------------------------------------------------------------------+
class CSignalDiagnostics
{
private:
   CLogger               *m_logger;
   const CIndicatorManager     *m_indicators;
   CMarketStructure      *m_structure;
   CSignalEngine         *m_signals;
   CPullbackEntryManager *m_pullback;
   CFilterManager        *m_filters;
   string                 m_symbol;
   ENUM_TIMEFRAMES        m_timeframe;
   bool                   m_enabled;

   string BoolStr(const bool value) const
   {
      return value ? "TRUE" : "FALSE";
   }

   string DirectionStr(const ENUM_SIGNAL direction) const
   {
      if(direction == SIGNAL_BUY)  return "BUY";
      if(direction == SIGNAL_SELL) return "SELL";
      return "NONE";
   }

   void AppendBlocker(string &blockers, const string name, const bool passed) const
   {
      if(passed)
         return;
      if(blockers != "")
         blockers += ", ";
      blockers += name;
   }

   void PrintDirectionReport(const ENUM_SIGNAL direction,
                             const string mode,
                             const int barsRemaining) const
   {
      if(m_logger == NULL || m_signals == NULL || m_pullback == NULL || m_indicators == NULL)
         return;

      const bool bos           = m_signals.DiagBOS(direction);
      const bool htfTrend      = m_signals.DiagHTFTrend(direction);
      const bool ltfTrend      = m_signals.DiagLTFTrend(direction);
      const bool adx           = m_signals.DiagADXFilter();
      const bool atrFilter     = m_signals.DiagATRFilter();
      const bool rangeFilter   = m_signals.DiagRangeFilter();
      const bool coreFilters   = m_signals.DiagCoreFilters();
      const bool armedValid    = m_signals.DiagValidateArmed(direction);
      const bool pullback      = m_pullback.CheckPullback(direction, m_indicators);
      const bool rsiMomentum   = m_pullback.CheckRSIMomentum(direction, m_indicators);
      const bool candleConfirm = m_pullback.CheckCandleConfirm(direction, m_indicators);

      const datetime barTime = iTime(m_symbol, m_timeframe, 1);
      string header = StringFormat("=== Bar %s | Mode=%s | Dir=%s",
                                   TimeToString(barTime, TIME_DATE | TIME_MINUTES),
                                   mode, DirectionStr(direction));
      if(barsRemaining > 0)
         header += StringFormat(" | BarsLeft=%d", barsRemaining);

      m_logger.Diag(header);
      m_logger.Diag(StringFormat("BOS                 = %s", BoolStr(bos)));
      m_logger.Diag(StringFormat("HTF Trend           = %s", BoolStr(htfTrend)));
      m_logger.Diag(StringFormat("LTF Trend           = %s", BoolStr(ltfTrend)));
      m_logger.Diag(StringFormat("ADX                 = %s", BoolStr(adx)));
      m_logger.Diag(StringFormat("ATR Filter          = %s", BoolStr(atrFilter)));
      m_logger.Diag(StringFormat("Pullback            = %s", BoolStr(pullback)));
      m_logger.Diag(StringFormat("RSI Momentum        = %s", BoolStr(rsiMomentum)));
      m_logger.Diag(StringFormat("%s = %s",
                                 (direction == SIGNAL_BUY ? "Bullish Candle     " : "Bearish Candle     "),
                                 BoolStr(candleConfirm)));
      m_logger.Diag(StringFormat("Range Filter        = %s", BoolStr(rangeFilter)));
      m_logger.Diag(StringFormat("Core Filters        = %s", BoolStr(coreFilters)));
      m_logger.Diag(StringFormat("Armed Validation    = %s", BoolStr(armedValid)));

      string blockers = "";
      if(StringCompare(mode, "SETUP_SCAN") == 0)
      {
         AppendBlocker(blockers, "BOS", bos);
         AppendBlocker(blockers, "HTF Trend", htfTrend);
         AppendBlocker(blockers, "LTF Trend", ltfTrend);
         AppendBlocker(blockers, "ADX", adx);
         AppendBlocker(blockers, "ATR Filter", atrFilter);
         AppendBlocker(blockers, "Range Filter", rangeFilter);
      }
      else
      {
         AppendBlocker(blockers, "Armed Validation", armedValid);
         AppendBlocker(blockers, "Pullback", pullback);
         AppendBlocker(blockers, "RSI Momentum", rsiMomentum);
         AppendBlocker(blockers, "Candle Confirmation", candleConfirm);
      }

      if(blockers == "")
         m_logger.Diag("BLOCKERS: none (all checked conditions passed)");
      else
         m_logger.Diag("BLOCKERS: " + blockers);

      if(!bos && StringCompare(mode, "SETUP_SCAN") == 0)
         m_logger.Diag("FAIL: BOS not present for " + DirectionStr(direction) + " setup.");
      if(!htfTrend)
      {
         m_logger.Diag("FAIL: HTF trend not aligned.");
         m_signals.LogHTFTrendDetail(direction);
      }
      if(!ltfTrend)
      {
         m_logger.Diag("FAIL: LTF trend not aligned.");
         m_signals.LogLTFTrendDetail(direction);
      }
      if(!adx)
      {
         m_logger.Diag("FAIL: ADX filter not passed.");
         m_signals.LogADXDetail();
      }
      if(!atrFilter)
      {
         m_logger.Diag("FAIL: ATR volatility filter not passed.");
         m_signals.LogATRDetail();
      }
      if(!rangeFilter)
      {
         m_logger.Diag("FAIL: Range filter flagged choppy/ranging market.");
         m_signals.LogRangeDetail();
      }
      if(StringCompare(mode, "ENTRY_CONFIRM") == 0)
      {
         if(!armedValid)
            m_logger.Diag("FAIL: Armed setup invalidated (core + HTF + LTF no longer aligned).");
         if(!pullback)
         {
            m_logger.Diag("FAIL: Pullback to EMA zone not complete.");
            m_pullback.LogPullbackDetail(direction, m_indicators);
         }
         if(!rsiMomentum)
         {
            m_logger.Diag("FAIL: RSI momentum not confirmed.");
            m_pullback.LogRSIDetail(direction, m_indicators);
         }
         if(!candleConfirm)
         {
            m_logger.Diag("FAIL: Candle confirmation not met.");
            m_pullback.LogCandleDetail(direction, m_indicators);
         }
      }
   }

public:
   CSignalDiagnostics(void) :
      m_logger(NULL),
      m_indicators(NULL),
      m_structure(NULL),
      m_signals(NULL),
      m_pullback(NULL),
      m_filters(NULL),
      m_symbol(""),
      m_timeframe(PERIOD_CURRENT),
      m_enabled(true)
   {}

   void Init(CLogger *logger,
             const CIndicatorManager *indicators,
             CMarketStructure *structure,
             CSignalEngine *signals,
             CPullbackEntryManager *pullback,
             CFilterManager *filters,
             const string symbol,
             const ENUM_TIMEFRAMES timeframe,
             const SSettings &settings)
   {
      m_logger     = logger;
      m_indicators = indicators;
      m_structure  = structure;
      m_signals    = signals;
      m_pullback   = pullback;
      m_filters    = filters;
      m_symbol     = symbol;
      m_timeframe  = timeframe;
      m_enabled    = settings.enableDiagnostics;
   }

   void PrintBarReport(const ENUM_SETUP_STATE setupState,
                       const ENUM_SIGNAL armedDirection) const
   {
      if(!m_enabled || m_logger == NULL)
         return;

      if(m_filters != NULL)
      {
         const bool spreadOk  = m_filters.IsSpreadAcceptable();
         const bool sessionOk = m_filters.IsWithinSession();
         m_logger.Diag(StringFormat("Pre-filters | Spread=%s Session=%s",
                                    BoolStr(spreadOk), BoolStr(sessionOk)));
         if(!spreadOk)
            m_logger.Diag("FAIL: Spread filter blocked entry evaluation.");
         if(!sessionOk)
            m_logger.Diag("FAIL: Session filter blocked entry evaluation.");
      }

      if(setupState != SETUP_NONE && armedDirection != SIGNAL_NONE)
      {
         PrintDirectionReport(armedDirection, "ENTRY_CONFIRM", m_pullback.GetBarsRemaining());
         return;
      }

      PrintDirectionReport(SIGNAL_BUY,  "SETUP_SCAN", 0);
      PrintDirectionReport(SIGNAL_SELL, "SETUP_SCAN", 0);
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

   void Init(CLogger *logger, const SSettings &settings)
   {
      m_logger           = logger;
      m_magic            = settings.magicNumber;
      m_useTrailing      = settings.useTrailingStop;
      m_trailStartAtr    = settings.trailStartAtr;
      m_trailStepAtr     = settings.trailStepAtr;
      m_useBreakEven     = settings.useBreakEven;
      m_beTriggerAtr     = settings.breakEvenTriggerAtr;
      m_beOffsetPoints   = settings.breakEvenOffsetPoints;

      m_trade.SetExpertMagicNumber(m_magic);
      m_trade.SetDeviationInPoints(EA_TRADE_DEVIATION_POINTS);
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

   void Init(CLogger *logger, const SSettings &settings)
   {
      m_logger       = logger;
      m_magic        = settings.magicNumber;
      m_comment      = settings.tradeComment;
      m_slMultiplier = settings.slAtrMultiplier;
      m_tpMultiplier = settings.tpAtrMultiplier;

      m_trade.SetExpertMagicNumber(m_magic);
      m_trade.SetDeviationInPoints(EA_TRADE_DEVIATION_POINTS);
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
//| SDirectionChecks - Snapshot of one direction's filter states      |
//+------------------------------------------------------------------+
struct SDirectionChecks
{
   bool bos;
   bool htf;
   bool ltf;
   bool adx;
   bool atr;
   bool range;
   bool pullback;
   bool rsi;
   bool candle;
};

//+------------------------------------------------------------------+
//| STradeAuditEntry - Snapshot captured at trade entry               |
//+------------------------------------------------------------------+
struct STradeAuditEntry
{
   int            tradeNumber;
   ENUM_SIGNAL    direction;
   datetime       entryTime;
   datetime       entryBarTime;
   double         entryPrice;
   bool           bosPass;
   bool           htfPass;
   bool           ltfPass;
   double         adxValue;
   double         atrValue;
   double         emaSeparation;
   double         rsiValue;
   double         pullbackDistance;
   bool           candleConfirm;
   double         stopLoss;
   double         takeProfit;
   double         slDistance;
   double         lotSize;
   ulong          positionId;
};

//+------------------------------------------------------------------+
//| CStrategyAudit - Per-trade entry/exit audit logging               |
//+------------------------------------------------------------------+
class CStrategyAudit
{
private:
   bool              m_enabled;
   CLogger          *m_logger;
   CExitManager     *m_exits;
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   ulong             m_magic;
   int               m_tradeCount;
   bool              m_hasActive;
   STradeAuditEntry  m_active;

   string PassFailLabel(const bool passed) const
   {
      return passed ? "PASS" : "FAIL";
   }

   string DealReasonLabel(const ENUM_DEAL_REASON reason) const
   {
      switch(reason)
      {
         case DEAL_REASON_SL:     return "Stop Loss";
         case DEAL_REASON_TP:     return "Take Profit";
         case DEAL_REASON_SO:     return "Stop Out";
         case DEAL_REASON_CLIENT: return "Client";
         case DEAL_REASON_MOBILE: return "Mobile";
         case DEAL_REASON_WEB:    return "Web";
         case DEAL_REASON_EXPERT:
            if(m_exits != NULL && m_exits.GetLastExitReason() != "")
               return m_exits.GetLastExitReason();
            return "Expert exit";
         default:                 return "Unknown";
      }
   }

   static double ComputePullbackDistance(const ENUM_SIGNAL direction,
                                         const CIndicatorManager *indicators)
   {
      if(indicators == NULL)
         return 0.0;

      double fastEma = 0.0;
      double atr     = 0.0;
      double open1 = 0.0, high1 = 0.0, low1 = 0.0, close1 = 0.0;

      if(!indicators.GetFastEMA(fastEma, 1) ||
         !indicators.GetATR(atr, 1) ||
         !indicators.GetBarOHLC(1, open1, high1, low1, close1) ||
         atr <= 0.0)
         return 0.0;

      if(direction == SIGNAL_BUY)
         return MathAbs(low1 - fastEma) / atr;

      if(direction == SIGNAL_SELL)
         return MathAbs(high1 - fastEma) / atr;

      return 0.0;
   }

   static double ComputeEmaSeparation(const CIndicatorManager *indicators)
   {
      double fastEma = 0.0;
      double slowEma = 0.0;
      double atr     = 0.0;

      if(indicators == NULL ||
         !indicators.GetFastEMA(fastEma, 1) ||
         !indicators.GetSlowEMA(slowEma, 1) ||
         !indicators.GetATR(atr, 1) ||
         atr <= 0.0)
         return 0.0;

      return MathAbs(fastEma - slowEma) / atr;
   }

   int CountHoldingBars(const datetime entryTime) const
   {
      if(entryTime <= 0)
         return 0;

      const int entryShift = iBarShift(m_symbol, m_timeframe, entryTime, true);
      if(entryShift < 0)
         return 0;

      return entryShift;
   }

   bool FindOurPosition(ulong &ticket, double &entryPrice,
                        double &sl, double &tp, double &volume,
                        long &positionId) const
   {
      ticket     = 0;
      positionId = 0;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         const ulong posTicket = PositionGetTicket(i);
         if(posTicket == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol)
            continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;

         ticket     = posTicket;
         entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         sl         = PositionGetDouble(POSITION_SL);
         tp         = PositionGetDouble(POSITION_TP);
         volume     = PositionGetDouble(POSITION_VOLUME);
         positionId = PositionGetInteger(POSITION_IDENTIFIER);
         return true;
      }
      return false;
   }

public:
   CStrategyAudit(void) :
      m_enabled(false),
      m_logger(NULL),
      m_exits(NULL),
      m_symbol(""),
      m_timeframe(PERIOD_CURRENT),
      m_magic(0),
      m_tradeCount(0),
      m_hasActive(false)
   {}

   void Init(CLogger *logger, const bool enabled, CExitManager *exits,
             const string symbol, const ENUM_TIMEFRAMES timeframe,
             const ulong magic)
   {
      m_logger    = logger;
      m_enabled   = enabled;
      m_exits     = exits;
      m_symbol    = symbol;
      m_timeframe = timeframe;
      m_magic     = magic;
      m_tradeCount = 0;
      m_hasActive = false;
   }

   bool IsEnabled(void) const { return m_enabled; }

   void RecordTradeEntry(const ENUM_SIGNAL signal,
                         const SDirectionChecks &checks,
                         const CIndicatorManager *indicators,
                         const double lotSize,
                         const datetime entryBarTime)
   {
      if(!m_enabled || m_logger == NULL || signal == SIGNAL_NONE || indicators == NULL)
         return;

      ulong ticket = 0;
      double entryPrice = 0.0, sl = 0.0, tp = 0.0, volume = 0.0;
      long positionId = 0;

      if(!FindOurPosition(ticket, entryPrice, sl, tp, volume, positionId))
         return;

      double adx = 0.0, atr = 0.0, rsi = 0.0;
      indicators.GetADX(adx, 1);
      indicators.GetATR(atr, 1);
      indicators.GetRSI(rsi, 1);

      m_tradeCount++;
      m_hasActive = true;

      m_active.tradeNumber      = m_tradeCount;
      m_active.direction        = signal;
      m_active.entryTime        = TimeCurrent();
      m_active.entryBarTime     = entryBarTime;
      m_active.entryPrice       = entryPrice;
      m_active.bosPass          = checks.bos;
      m_active.htfPass          = checks.htf;
      m_active.ltfPass          = checks.ltf;
      m_active.adxValue         = adx;
      m_active.atrValue         = atr;
      m_active.emaSeparation    = ComputeEmaSeparation(indicators);
      m_active.rsiValue         = rsi;
      m_active.pullbackDistance = ComputePullbackDistance(signal, indicators);
      m_active.candleConfirm    = checks.candle;
      m_active.stopLoss         = sl;
      m_active.takeProfit       = tp;
      m_active.slDistance       = MathAbs(entryPrice - sl);
      m_active.lotSize          = lotSize;
      m_active.positionId       = (ulong)positionId;

      m_logger.Audit("========== TRADE ENTRY ==========");
      m_logger.Audit(StringFormat("Trade Number:        %d", m_active.tradeNumber));
      m_logger.Audit(StringFormat("Direction:           %s",
                                  (signal == SIGNAL_BUY ? "BUY" : "SELL")));
      m_logger.Audit(StringFormat("Entry Time:          %s",
                                  TimeToString(m_active.entryTime,
                                               TIME_DATE | TIME_MINUTES | TIME_SECONDS)));
      m_logger.Audit(StringFormat("Entry Price:         %.5f", m_active.entryPrice));
      m_logger.Audit(StringFormat("BOS:                 %s", PassFailLabel(m_active.bosPass)));
      m_logger.Audit(StringFormat("HTF Trend:           %s", PassFailLabel(m_active.htfPass)));
      m_logger.Audit(StringFormat("LTF Trend:           %s", PassFailLabel(m_active.ltfPass)));
      m_logger.Audit(StringFormat("ADX Value:           %.2f", m_active.adxValue));
      m_logger.Audit(StringFormat("ATR Value:           %.5f", m_active.atrValue));
      m_logger.Audit(StringFormat("EMA Separation:      %.3f (ATR units)", m_active.emaSeparation));
      m_logger.Audit(StringFormat("RSI Value:           %.2f", m_active.rsiValue));
      m_logger.Audit(StringFormat("Pullback Distance:   %.3f (ATR units)", m_active.pullbackDistance));
      m_logger.Audit(StringFormat("Candle Confirmation: %s", PassFailLabel(m_active.candleConfirm)));
      m_logger.Audit(StringFormat("Stop Loss:           %.5f", m_active.stopLoss));
      m_logger.Audit(StringFormat("Take Profit:         %.5f", m_active.takeProfit));
      m_logger.Audit("=================================");
   }

   void HandleDealAdd(const ulong dealTicket)
   {
      if(!m_enabled || !m_hasActive || m_logger == NULL)
         return;

      if(!HistoryDealSelect(dealTicket))
         return;

      if(HistoryDealGetString(DEAL_SYMBOL) != m_symbol)
         return;
      if((ulong)HistoryDealGetInteger(DEAL_MAGIC) != m_magic)
         return;

      const ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(DEAL_ENTRY);
      if(dealEntry != DEAL_ENTRY_OUT && dealEntry != DEAL_ENTRY_OUT_BY)
         return;

      const ulong dealPositionId = (ulong)HistoryDealGetInteger(DEAL_POSITION_ID);
      if(m_active.positionId != 0 && dealPositionId != m_active.positionId)
         return;

      const double profit = HistoryDealGetDouble(DEAL_PROFIT) +
                            HistoryDealGetDouble(DEAL_SWAP) +
                            HistoryDealGetDouble(DEAL_COMMISSION);

      const ENUM_DEAL_REASON reasonCode = (ENUM_DEAL_REASON)HistoryDealGetInteger(DEAL_REASON);
      const string exitReason = DealReasonLabel(reasonCode);

      const double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      const double tickSize  = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      double initialRisk = 0.0;
      if(tickSize > 0.0 && m_active.slDistance > 0.0)
         initialRisk = (m_active.slDistance / tickSize) * tickValue * m_active.lotSize;

      const double rMultiple = (initialRisk > 0.0) ? profit / initialRisk : 0.0;
      const int holdingBars = CountHoldingBars(m_active.entryTime);

      m_logger.Audit("========== TRADE EXIT ==========");
      m_logger.Audit(StringFormat("Trade Number:        %d", m_active.tradeNumber));
      m_logger.Audit(StringFormat("Exit Reason:         %s", exitReason));
      m_logger.Audit(StringFormat("Profit/Loss:         %.2f", profit));
      m_logger.Audit(StringFormat("R-Multiple:          %.2fR", rMultiple));
      m_logger.Audit(StringFormat("Holding Bars:        %d", holdingBars));
      m_logger.Audit("=================================");

      m_hasActive = false;
   }
};

//+------------------------------------------------------------------+
//| CPipelineStats - Backtest entry pipeline counters                  |
//+------------------------------------------------------------------+
class CPipelineStats
{
public:
   int barsChecked;
   int buySetups;
   int sellSetups;
   int bosFound;
   int htfPassed;
   int ltfPassed;
   int adxPassed;
   int atrPassed;
   int rangePassed;
   int pullbacksFound;
   int rsiPassed;
   int candlePassed;
   int tradesExecuted;
   int rejectBOS;
   int rejectHTF;
   int rejectLTF;
   int rejectADX;
   int rejectATR;
   int rejectRange;
   int rejectPullback;
   int rejectRSI;
   int rejectCandle;
   int setupsArmed;
   int rejectSpread;
   int rejectSession;
   int rejectRisk;
   int rejectPosition;
   int rejectArmedValidation;
   int rejectExitBar;
   int rejectPullbackExpired;
   int rejectOrderSend;

   CPipelineStats(void) { Reset(); }

   void Reset(void)
   {
      barsChecked           = 0;
      buySetups             = 0;
      sellSetups            = 0;
      bosFound              = 0;
      htfPassed             = 0;
      ltfPassed             = 0;
      adxPassed             = 0;
      atrPassed             = 0;
      rangePassed           = 0;
      pullbacksFound        = 0;
      rsiPassed             = 0;
      candlePassed          = 0;
      tradesExecuted        = 0;
      rejectBOS             = 0;
      rejectHTF             = 0;
      rejectLTF             = 0;
      rejectADX             = 0;
      rejectATR             = 0;
      rejectRange           = 0;
      rejectPullback        = 0;
      rejectRSI             = 0;
      rejectCandle          = 0;
      setupsArmed           = 0;
      rejectSpread          = 0;
      rejectSession         = 0;
      rejectRisk            = 0;
      rejectPosition        = 0;
      rejectArmedValidation = 0;
      rejectExitBar         = 0;
      rejectPullbackExpired = 0;
      rejectOrderSend       = 0;
   }

   void PrintFinalReport(CLogger *logger) const
   {
      if(logger == NULL)
         return;

      logger.Info("==========================");
      logger.Info("FINAL DEBUG REPORT");
      logger.Info("==========================");
      logger.Info(StringFormat("Bars Checked:      %d", barsChecked));
      logger.Info(StringFormat("BUY Setups:        %d", buySetups));
      logger.Info(StringFormat("SELL Setups:       %d", sellSetups));
      logger.Info(StringFormat("BOS Found:         %d", bosFound));
      logger.Info(StringFormat("HTF Passed:        %d", htfPassed));
      logger.Info(StringFormat("LTF Passed:        %d", ltfPassed));
      logger.Info(StringFormat("ADX Passed:        %d", adxPassed));
      logger.Info(StringFormat("ATR Passed:        %d", atrPassed));
      logger.Info(StringFormat("Range Passed:      %d", rangePassed));
      logger.Info(StringFormat("Pullbacks Found:   %d", pullbacksFound));
      logger.Info(StringFormat("RSI Passed:        %d", rsiPassed));
      logger.Info(StringFormat("Candle Passed:     %d", candlePassed));
      logger.Info(StringFormat("Trades Executed:   %d", tradesExecuted));
      logger.Info(StringFormat("Setups Armed:      %d", setupsArmed));
      logger.Info("");
      logger.Info(StringFormat("Reject BOS:        %d", rejectBOS));
      logger.Info(StringFormat("Reject HTF:        %d", rejectHTF));
      logger.Info(StringFormat("Reject LTF:        %d", rejectLTF));
      logger.Info(StringFormat("Reject ADX:        %d", rejectADX));
      logger.Info(StringFormat("Reject ATR:        %d", rejectATR));
      logger.Info(StringFormat("Reject Range:      %d", rejectRange));
      logger.Info(StringFormat("Reject Pullback:   %d", rejectPullback));
      logger.Info(StringFormat("Reject RSI Momentum:   %d", rejectRSI));
      logger.Info(StringFormat("Reject Candle:     %d", rejectCandle));
      logger.Info("==========================");
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
   CSignalDiagnostics    m_diagnostics;
   CRiskManager          m_risk;
   CFilterManager        m_filters;
   CPositionManager      m_positions;
   CTradeExecutor        m_executor;

   CPipelineStats        m_stats;
   CStrategyAudit        m_audit;

   string             m_symbol;
   ENUM_TIMEFRAMES    m_timeframe;
   datetime           m_lastBarTime;
   datetime           m_lastExitBarTime;

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

   string SignalLabel(const ENUM_SIGNAL direction) const
   {
      if(direction == SIGNAL_BUY)
         return "BUY";
      if(direction == SIGNAL_SELL)
         return "SELL";
      return "NONE";
   }

   string CheckLine(const string name, const bool passed) const
   {
      string padding = "....................";
      const int dotsNeeded = MathMax(1, 20 - StringLen(name));
      return name + StringSubstr(padding, 0, dotsNeeded) + " " + (passed ? "PASS" : "FAIL");
   }

   SDirectionChecks CollectChecks(const ENUM_SIGNAL direction) const
   {
      SDirectionChecks checks;
      checks.bos      = m_signals.DiagBOS(direction);
      checks.htf      = m_signals.DiagHTFTrend(direction);
      checks.ltf      = m_signals.DiagLTFTrend(direction);
      checks.adx      = m_signals.DiagADXFilter();
      checks.atr      = m_signals.DiagATRFilter();
      checks.range    = m_signals.DiagRangeFilter();
      checks.pullback = m_pullback.CheckPullback(direction, GetPointer(m_indicators));
      checks.rsi      = m_pullback.CheckRSIMomentum(direction, GetPointer(m_indicators));
      checks.candle   = m_pullback.CheckCandleConfirm(direction, GetPointer(m_indicators));
      return checks;
   }

   bool IsSetupReady(const SDirectionChecks &checks) const
   {
      return (checks.bos && checks.htf && checks.ltf &&
              checks.adx && checks.atr && checks.range);
   }

   void RecordSetupCandidateStats(const ENUM_SIGNAL direction,
                                  const SDirectionChecks &checks)
   {
      if(direction == SIGNAL_NONE || !checks.bos)
         return;

      m_stats.bosFound++;

      if(checks.htf)
         m_stats.htfPassed++;
      else
         m_stats.rejectHTF++;

      if(checks.ltf)
         m_stats.ltfPassed++;
      else
         m_stats.rejectLTF++;

      if(checks.adx)
         m_stats.adxPassed++;
      else
         m_stats.rejectADX++;

      if(checks.atr)
         m_stats.atrPassed++;
      else
         m_stats.rejectATR++;

      if(checks.range)
         m_stats.rangePassed++;
      else
         m_stats.rejectRange++;
   }

   void RecordEntryAttemptStats(const ENUM_SIGNAL direction,
                                const SDirectionChecks &checks)
   {
      if(direction == SIGNAL_NONE)
         return;

      if(checks.pullback)
         m_stats.pullbacksFound++;
      else
         m_stats.rejectPullback++;

      if(checks.rsi)
         m_stats.rsiPassed++;
      else
         m_stats.rejectRSI++;

      if(checks.candle)
         m_stats.candlePassed++;
      else
         m_stats.rejectCandle++;
   }

   void LogSetupRejection(const string sideLabel, const SDirectionChecks &checks)
   {
      if(!g_settings.EnablePipelineLog())
         return;

      if(!checks.bos)
      {
         m_logger.Pipe(sideLabel + " Rejected because BOS not found.");
         return;
      }
      if(!checks.htf)
      {
         m_logger.Pipe(sideLabel + " Rejected because HTF trend not aligned.");
         return;
      }
      if(!checks.ltf)
      {
         m_logger.Pipe(sideLabel + " Rejected because LTF trend not aligned.");
         return;
      }
      if(!checks.adx)
      {
         m_logger.Pipe(sideLabel + " Rejected because ADX below threshold.");
         return;
      }
      if(!checks.atr)
      {
         m_logger.Pipe(sideLabel + " Rejected because ATR filter failed.");
         return;
      }
      if(!checks.range)
      {
         m_logger.Pipe(sideLabel + " Rejected because Range filter failed.");
         return;
      }
   }

   void LogEntryRejection(const string sideLabel, const ENUM_SIGNAL direction,
                          const SDirectionChecks &checks)
   {
      if(!g_settings.EnablePipelineLog())
         return;

      if(!checks.pullback)
      {
         m_logger.Pipe(sideLabel + " Rejected because Pullback never happened.");
         return;
      }
      if(!checks.rsi)
      {
         m_logger.Pipe(sideLabel + " Rejected because RSI Momentum missing.");
         return;
      }
      if(!checks.candle)
      {
         m_logger.Pipe(sideLabel + (direction == SIGNAL_BUY ?
                        " Rejected because Bullish Candle confirmation failed." :
                        " Rejected because Bearish Candle confirmation failed."));
      }
   }

   void PrintDirectionBlock(const string sideLabel, const ENUM_SIGNAL direction,
                            const bool logRejections, const bool entryPhase)
   {
      if(!g_settings.EnablePipelineLog())
         return;

      const SDirectionChecks checks = CollectChecks(direction);

      m_logger.Pipe("");
      m_logger.Pipe(sideLabel + " CHECK");
      m_logger.Pipe("");
      m_logger.Pipe(CheckLine("BOS", checks.bos));
      m_logger.Pipe(CheckLine("HTF Trend", checks.htf));
      m_logger.Pipe(CheckLine("LTF Trend", checks.ltf));
      m_logger.Pipe(CheckLine("ADX", checks.adx));
      m_logger.Pipe(CheckLine("ATR", checks.atr));
      m_logger.Pipe(CheckLine("Range Filter", checks.range));
      m_logger.Pipe(CheckLine("Pullback", checks.pullback));
      m_logger.Pipe(CheckLine("RSI Momentum", checks.rsi));
      m_logger.Pipe(CheckLine((direction == SIGNAL_BUY ? "Bullish Candle" : "Bearish Candle"), checks.candle));

      if(!logRejections)
         return;

      if(entryPhase)
         LogEntryRejection(sideLabel, direction, checks);
      else if(checks.bos)
         LogSetupRejection(sideLabel, checks);
   }

   void PrintBarDebugReport(const datetime barTime, const bool entryPhase,
                            const ENUM_SIGNAL armedDir)
   {
      if(!g_settings.EnablePipelineLog())
         return;

      m_stats.barsChecked++;

      m_logger.Pipe("=================================================");
      m_logger.Pipe("BAR: " + TimeToString(barTime, TIME_DATE | TIME_MINUTES));

      if(entryPhase && armedDir != SIGNAL_NONE)
         PrintDirectionBlock(SignalLabel(armedDir), armedDir, false, true);
      else
      {
         PrintDirectionBlock("BUY", SIGNAL_BUY, false, false);
         PrintDirectionBlock("SELL", SIGNAL_SELL, false, false);
      }

      m_logger.Pipe("=================================================");
   }

   void RejectAndLog(const string reason, int &counter)
   {
      counter++;
      if(g_settings.EnablePipelineLog())
         m_logger.Pipe("REJECTED: " + reason);
   }

public:
   CExpertAdvisor(void) :
      m_symbol(_Symbol),
      m_timeframe(PERIOD_CURRENT),
      m_lastBarTime(0),
      m_lastExitBarTime(0)
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
      SSettings settings = g_settings.GetCopy();

      m_symbol          = _Symbol;
      m_timeframe       = PERIOD_CURRENT;
      m_lastBarTime     = iTime(m_symbol, m_timeframe, 0);
      m_lastExitBarTime = 0;
      m_stats.Reset();

      m_logger.Init(settings.logLevel, EA_PRODUCT_NAME);
      m_logger.Info(StringFormat("Initializing %s v%s...", EA_PRODUCT_NAME, EA_VERSION_STRING));

      g_settings.PrintStartupConfig(&m_logger, m_symbol, m_timeframe);

      m_indicators.SetLogger(&m_logger);
      if(!m_indicators.Init(m_symbol, m_timeframe, settings))
         return false;

      m_structure.Init(m_symbol, m_timeframe, &m_logger, settings);

      m_signals.Init(GetPointer(m_indicators), GetPointer(m_structure), &m_logger, settings);
      m_pullback.Init(&m_logger, settings);
      m_exits.Init(&m_logger, settings,
                   GetPointer(m_indicators), GetPointer(m_structure));
      if(!m_exits.RefreshSymbol(m_symbol))
      {
         m_logger.Error("Failed to bind exit manager to symbol.");
         return false;
      }

      m_risk.Init(&m_logger, settings);
      if(!m_risk.RefreshSymbol(m_symbol))
      {
         m_logger.Error("Failed to bind risk manager to symbol.");
         return false;
      }

      m_filters.Init(&m_logger, settings);
      if(!m_filters.RefreshSymbol(m_symbol))
      {
         m_logger.Error("Failed to bind filter manager to symbol.");
         return false;
      }

      m_diagnostics.Init(&m_logger,
                         GetPointer(m_indicators),
                         GetPointer(m_structure),
                         GetPointer(m_signals),
                         GetPointer(m_pullback),
                         GetPointer(m_filters),
                         m_symbol,
                         m_timeframe,
                         settings);

      m_positions.Init(&m_logger, settings);
      if(!m_positions.RefreshSymbol(m_symbol))
      {
         m_logger.Error("Failed to bind position manager to symbol.");
         return false;
      }

      m_executor.Init(&m_logger, settings);
      if(!m_executor.RefreshSymbol(m_symbol))
      {
         m_logger.Error("Failed to bind trade executor to symbol.");
         return false;
      }

      m_logger.Info(StringFormat("EA ready | Symbol=%s Magic=%I64u",
                                 m_symbol, settings.magicNumber));

      m_audit.Init(&m_logger, settings.enableStrategyAudit, &m_exits,
                   m_symbol, m_timeframe, settings.magicNumber);
      if(settings.enableStrategyAudit)
         m_logger.Info("Strategy Audit Mode: ENABLED");

      return true;
   }

   void Deinit(void)
   {
      m_stats.PrintFinalReport(&m_logger);
      m_pullback.Reset();
      m_indicators.Deinit();
      m_logger.Info("Expert Advisor deinitialized.");
   }

   void OnTick(void)
   {
      double atrValue = 0.0;

      if(m_exits.CheckAndExit())
      {
         m_lastExitBarTime = iTime(m_symbol, m_timeframe, 0);
         m_pullback.Reset();
         m_logger.Debug("Exit triggered - pullback state cleared.");
      }

      if(m_indicators.GetATR(atrValue) && m_positions.HasOpenPosition())
         m_positions.ManageOpenPosition(atrValue);

      if(!IsNewBar())
         return;

      m_logger.Debug("New bar - evaluating pullback and setup conditions.");

      const ENUM_SETUP_STATE setupState = m_pullback.GetState();
      const ENUM_SIGNAL armedDir        = GetArmedDirection();
      const datetime barTime            = iTime(m_symbol, m_timeframe, 1);
      const bool entryPhase             = (setupState != SETUP_NONE && armedDir != SIGNAL_NONE);

      if(g_settings.EnableDiagnostics())
         m_diagnostics.PrintBarReport(setupState, armedDir);

      PrintBarDebugReport(barTime, entryPhase, armedDir);

      const bool spreadOk  = m_filters.IsSpreadAcceptable();
      const bool sessionOk = m_filters.IsWithinSession();
      const bool exitBarBlocked = (m_lastExitBarTime == m_lastBarTime);
      const bool canAttemptEntry = (!m_positions.HasOpenPosition() &&
                                    !exitBarBlocked && spreadOk && sessionOk);

      ENUM_SIGNAL signal = SIGNAL_NONE;

      // Armed state machine: always advance timer; confirm only when entry filters allow
      if(m_pullback.GetState() != SETUP_NONE)
      {
         const ENUM_SIGNAL confirmDir = GetArmedDirection();
         const int barsBefore         = m_pullback.GetBarsRemaining();

         if(confirmDir != SIGNAL_NONE && canAttemptEntry)
         {
            const bool armedValid = m_signals.ValidateArmedSetup(confirmDir);
            if(armedValid)
            {
               signal = m_pullback.TryConfirmEntry(GetPointer(m_indicators));

               const SDirectionChecks entryChecks = CollectChecks(confirmDir);
               RecordEntryAttemptStats(confirmDir, entryChecks);

               if(g_settings.EnablePipelineLog())
               {
                  PrintDirectionBlock(SignalLabel(confirmDir), confirmDir, true, true);
                  if(signal == SIGNAL_NONE)
                     LogEntryRejection(SignalLabel(confirmDir), confirmDir, entryChecks);
               }
            }
            else
            {
               m_pullback.Reset();
               RejectAndLog(StringFormat("Armed %s setup invalidated - core/HTF/LTF filters lost",
                                         SignalLabel(confirmDir)),
                            m_stats.rejectArmedValidation);
            }
         }

         if(m_pullback.GetState() != SETUP_NONE)
         {
            m_pullback.DecrementBar();

            if(m_pullback.GetState() == SETUP_NONE && barsBefore > 0)
            {
               RejectAndLog(StringFormat("Pullback setup expired on bar %s",
                                         TimeToString(barTime, TIME_DATE | TIME_MINUTES)),
                            m_stats.rejectPullbackExpired);
            }
         }
      }

      if(m_positions.HasOpenPosition())
      {
         RejectAndLog("Position already open for this symbol", m_stats.rejectPosition);
         return;
      }

      if(exitBarBlocked)
      {
         RejectAndLog("Exit occurred on this bar - re-entry blocked", m_stats.rejectExitBar);
         if(signal == SIGNAL_NONE)
            return;
      }

      if(!spreadOk)
      {
         RejectAndLog("Spread filter blocked entry", m_stats.rejectSpread);
         if(signal == SIGNAL_NONE)
            return;
      }
      if(!sessionOk)
      {
         RejectAndLog("Session filter blocked entry", m_stats.rejectSession);
         if(signal == SIGNAL_NONE)
            return;
      }

      if(signal == SIGNAL_NONE && m_pullback.GetState() == SETUP_NONE)
      {
         const SDirectionChecks buyChecks  = CollectChecks(SIGNAL_BUY);
         const SDirectionChecks sellChecks = CollectChecks(SIGNAL_SELL);

         if(buyChecks.bos)
            RecordSetupCandidateStats(SIGNAL_BUY, buyChecks);
         if(sellChecks.bos)
            RecordSetupCandidateStats(SIGNAL_SELL, sellChecks);

         const ENUM_SIGNAL setup = m_signals.EvaluateSetup();
         if(setup != SIGNAL_NONE)
         {
            if(setup == SIGNAL_BUY)
               m_stats.buySetups++;
            else if(setup == SIGNAL_SELL)
               m_stats.sellSetups++;

            m_pullback.ArmSetup(setup);
            m_stats.setupsArmed++;

            if(g_settings.EnablePipelineLog())
               m_logger.Pipe(StringFormat("SETUP ARMED: %s on bar %s",
                                          SignalLabel(setup),
                                          TimeToString(barTime, TIME_DATE | TIME_MINUTES)));
         }
         else if(g_settings.EnablePipelineLog())
         {
            if(buyChecks.bos)
               LogSetupRejection("BUY", buyChecks);
            if(sellChecks.bos)
               LogSetupRejection("SELL", sellChecks);
         }
      }

      if(signal == SIGNAL_NONE)
         return;

      if(!m_indicators.GetATR(atrValue) || atrValue <= 0.0)
      {
         RejectAndLog("ATR unavailable for trade execution", m_stats.rejectRisk);
         return;
      }

      const double slDistance = g_settings.SlAtrMultiplier() * atrValue;
      const double lotSize    = m_risk.CalculateLotSize(slDistance);

      if(lotSize <= 0.0)
      {
         RejectAndLog("Lot size calculation returned zero", m_stats.rejectRisk);
         return;
      }

      if(m_executor.OpenTrade(signal, lotSize, atrValue))
      {
         m_stats.tradesExecuted++;
         if(g_settings.EnablePipelineLog())
            m_logger.Pipe(StringFormat("TRADE EXECUTED: %s | Lot=%.2f | Bar=%s",
                                       SignalLabel(signal), lotSize,
                                       TimeToString(barTime, TIME_DATE | TIME_MINUTES)));

         if(g_settings.EnableStrategyAudit())
         {
            const SDirectionChecks auditChecks = CollectChecks(signal);
            m_audit.RecordTradeEntry(signal, auditChecks, GetPointer(m_indicators),
                                     lotSize, barTime);
         }
      }
      else
      {
         RejectAndLog("Order send failed at broker", m_stats.rejectOrderSend);
      }
   }

   void HandleTradeTransaction(const ulong dealTicket)
   {
      m_audit.HandleDealAdd(dealTicket);
   }
};

//+------------------------------------------------------------------+
//| Global instances                                                  |
//+------------------------------------------------------------------+
CSettingsManager g_settings;
CExpertAdvisor   g_ea;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit(void)
{
   g_settings.LoadFromInputs();

   string configError = "";
   if(!g_settings.Validate(configError))
   {
      Print(EA_PRODUCT_NAME, " [ERROR] Configuration validation failed: ", configError);
      return INIT_FAILED;
   }

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
//| Trade transaction handler (strategy audit exit logging)           |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
      g_ea.HandleTradeTransaction(trans.deal);
}
//+------------------------------------------------------------------+
