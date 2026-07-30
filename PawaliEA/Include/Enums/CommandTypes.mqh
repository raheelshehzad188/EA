//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Remote command types                        |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_ENUMS_COMMAND_TYPES_MQH
#define PAWALI_EA_ENUMS_COMMAND_TYPES_MQH

enum ENUM_PAWALI_COMMAND
{
   PAWALI_CMD_UNKNOWN        = 0,
   PAWALI_CMD_PAUSE_TRADING  = 1,
   PAWALI_CMD_RESUME_TRADING = 2,
   PAWALI_CMD_UPDATE_SETTINGS= 3,
   PAWALI_CMD_FORCE_SYNC     = 4,
   PAWALI_CMD_RESTART_EA     = 5,
   PAWALI_CMD_CLOSE_ALL      = 6,
   PAWALI_CMD_CLOSE_BUY      = 7,
   PAWALI_CMD_CLOSE_SELL     = 8,
   PAWALI_CMD_DISABLE_BUY    = 9,
   PAWALI_CMD_DISABLE_SELL   = 10,
   PAWALI_CMD_REDUCE_RISK    = 11
};

inline ENUM_PAWALI_COMMAND PawaliCommandFromString(const string value)
{
   if(value == "PAUSE_TRADING")   return PAWALI_CMD_PAUSE_TRADING;
   if(value == "RESUME_TRADING")  return PAWALI_CMD_RESUME_TRADING;
   if(value == "UPDATE_SETTINGS") return PAWALI_CMD_UPDATE_SETTINGS;
   if(value == "FORCE_SYNC")      return PAWALI_CMD_FORCE_SYNC;
   if(value == "RESTART_EA")      return PAWALI_CMD_RESTART_EA;
   if(value == "CLOSE_ALL")       return PAWALI_CMD_CLOSE_ALL;
   if(value == "CLOSE_BUY")       return PAWALI_CMD_CLOSE_BUY;
   if(value == "CLOSE_SELL")      return PAWALI_CMD_CLOSE_SELL;
   if(value == "DISABLE_BUY")     return PAWALI_CMD_DISABLE_BUY;
   if(value == "DISABLE_SELL")    return PAWALI_CMD_DISABLE_SELL;
   if(value == "REDUCE_RISK")     return PAWALI_CMD_REDUCE_RISK;
   return PAWALI_CMD_UNKNOWN;
}

inline string PawaliCommandToString(const ENUM_PAWALI_COMMAND command)
{
   switch(command)
   {
      case PAWALI_CMD_PAUSE_TRADING:   return "PAUSE_TRADING";
      case PAWALI_CMD_RESUME_TRADING:  return "RESUME_TRADING";
      case PAWALI_CMD_UPDATE_SETTINGS: return "UPDATE_SETTINGS";
      case PAWALI_CMD_FORCE_SYNC:      return "FORCE_SYNC";
      case PAWALI_CMD_RESTART_EA:      return "RESTART_EA";
      case PAWALI_CMD_CLOSE_ALL:       return "CLOSE_ALL";
      case PAWALI_CMD_CLOSE_BUY:       return "CLOSE_BUY";
      case PAWALI_CMD_CLOSE_SELL:      return "CLOSE_SELL";
      case PAWALI_CMD_DISABLE_BUY:     return "DISABLE_BUY";
      case PAWALI_CMD_DISABLE_SELL:    return "DISABLE_SELL";
      case PAWALI_CMD_REDUCE_RISK:     return "REDUCE_RISK";
      default:                         return "UNKNOWN";
   }
}

#endif
