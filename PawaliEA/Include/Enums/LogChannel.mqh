//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Log channel identifiers                     |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_ENUMS_LOG_CHANNEL_MQH
#define PAWALI_EA_ENUMS_LOG_CHANNEL_MQH

enum ENUM_PAWALI_LOG_CHANNEL
{
   PAWALI_LOG_EXPERT     = 0,
   PAWALI_LOG_API        = 1,
   PAWALI_LOG_TRADE      = 2,
   PAWALI_LOG_ERROR      = 3,
   PAWALI_LOG_PERFORMANCE= 4
};

inline string PawaliLogChannelFileName(const ENUM_PAWALI_LOG_CHANNEL channel)
{
   switch(channel)
   {
      case PAWALI_LOG_API:         return "API.log";
      case PAWALI_LOG_TRADE:       return "Trade.log";
      case PAWALI_LOG_ERROR:       return "Error.log";
      case PAWALI_LOG_PERFORMANCE: return "Performance.log";
      default:                     return "Expert.log";
   }
}

#endif
