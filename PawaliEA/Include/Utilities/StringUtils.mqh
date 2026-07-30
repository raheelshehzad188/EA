//+------------------------------------------------------------------+
//| PawaliEA Enterprise - String utilities                            |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_UTILITIES_STRING_UTILS_MQH
#define PAWALI_EA_UTILITIES_STRING_UTILS_MQH

class CPawaliStringUtils
{
public:
   static string Trim(const string value)
   {
      string result = value;
      StringTrimLeft(result);
      StringTrimRight(result);
      return result;
   }

   static string EscapeJson(const string value)
   {
      string out = value;
      StringReplace(out, "\\", "\\\\");
      StringReplace(out, "\"", "\\\"");
      StringReplace(out, "\r", "\\r");
      StringReplace(out, "\n", "\\n");
      StringReplace(out, "\t", "\\t");
      return out;
   }

   static bool StartsWith(const string value, const string prefix)
   {
      return (StringFind(value, prefix) == 0);
   }

   static string GenerateUuid(void)
   {
      return StringFormat("%I64u-%u-%u",
                          (ulong)TimeLocal(),
                          GetTickCount(),
                          MathRand());
   }
};

#endif
