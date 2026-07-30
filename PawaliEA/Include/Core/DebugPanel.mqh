//+------------------------------------------------------------------+
//| PawaliEA Enterprise - On-chart debug panel                        |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_CORE_DEBUG_PANEL_MQH
#define PAWALI_EA_CORE_DEBUG_PANEL_MQH

#include "Diagnostics.mqh"

#define PAWALI_PANEL_PREFIX "PAWALI_PANEL_"

class CPawaliDebugPanel
{
private:
   bool   m_enabled;
   string m_prefix;
   int    m_corner;
   int    m_x;
   int    m_y;
   int    m_lineHeight;

   void DeleteObjects(void)
   {
      const int total = ObjectsTotal(0, 0, -1);
      for(int i = total - 1; i >= 0; i--)
      {
         const string name = ObjectName(0, i, 0, -1);
         if(StringFind(name, m_prefix) == 0)
            ObjectDelete(0, name);
      }
   }

   void DrawLine(const int lineIndex, const string text, const color clr) const
   {
      const string name = m_prefix + IntegerToString(lineIndex);
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, m_corner);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, m_x);
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
         ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      }

      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, m_y + lineIndex * m_lineHeight);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   }

public:
   CPawaliDebugPanel(void) :
      m_enabled(true),
      m_prefix(PAWALI_PANEL_PREFIX),
      m_corner(CORNER_LEFT_UPPER),
      m_x(10),
      m_y(20),
      m_lineHeight(16)
   {}

   void SetEnabled(const bool enabled)
   {
      m_enabled = enabled;
      if(!m_enabled)
         DeleteObjects();
   }

   void Render(const SPawaliDiagnosticsSnapshot &snapshot) const
   {
      if(!m_enabled)
         return;

      DrawLine(0, "PawaliEA Enterprise", clrWhite);
      DrawLine(1, "Connection: " + PawaliConnectionStatusLabel(snapshot.connectionStatus),
               snapshot.connectionStatus == PAWALI_CONN_ONLINE ? clrLime : clrOrange);
      DrawLine(2, "License: " + PawaliLicenseStatusLabel(snapshot.licenseStatus),
               snapshot.licenseStatus == PAWALI_LICENSE_VALID ? clrLime : clrRed);
      DrawLine(3, StringFormat("API Status: %d", (int)snapshot.apiStatus), clrSilver);
      DrawLine(4, "Strategy: " + snapshot.strategyVersion, clrAqua);
      DrawLine(5, "Heartbeat: " + TimeToString(snapshot.lastHeartbeatAt, TIME_DATE | TIME_SECONDS), clrSilver);
      DrawLine(6, "Last Sync: " + TimeToString(snapshot.lastTradeSyncAt, TIME_DATE | TIME_SECONDS), clrSilver);
      DrawLine(7, StringFormat("Queue: %d | Replay: %d",
                               snapshot.pendingQueueCount,
                               snapshot.queueReplayCount), clrYellow);
      DrawLine(8, StringFormat("API Streak: %d | HB Fail: %d",
                               snapshot.apiFailureStreak,
                               snapshot.heartbeatFailures), clrSilver);
      DrawLine(9, snapshot.tradingPaused ? "Trading: PAUSED" : "Trading: ACTIVE",
               snapshot.tradingPaused ? clrOrange : clrLime);
   }

   void Clear(void)
   {
      DeleteObjects();
   }
};

#endif
