//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Time utilities                              |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_UTILITIES_TIME_UTILS_MQH
#define PAWALI_EA_UTILITIES_TIME_UTILS_MQH

class CPawaliTimeUtils
{
public:
   static string ToIso8601(const datetime value)
   {
      return TimeToString(value, TIME_DATE | TIME_SECONDS);
   }

   static bool IsExpired(const datetime expiresAt)
   {
      if(expiresAt <= 0)
         return true;
      return (TimeCurrent() >= expiresAt);
   }

   static datetime AddSeconds(const datetime base, const int seconds)
   {
      return base + seconds;
   }
};

#endif
