//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Timer manager                                |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_CORE_TIMER_MANAGER_MQH
#define PAWALI_EA_CORE_TIMER_MANAGER_MQH

#define PAWALI_TIMER_HEARTBEAT 1001
#define PAWALI_TIMER_COMMANDS  1002
#define PAWALI_TIMER_SYNC      1003

class CPawaliTimerManager
{
private:
   int m_heartbeatIntervalSec;
   int m_commandIntervalSec;
   int m_syncIntervalSec;

public:
   CPawaliTimerManager(void) :
      m_heartbeatIntervalSec(60),
      m_commandIntervalSec(15),
      m_syncIntervalSec(30)
   {}

   void Configure(const int heartbeatSec, const int commandSec, const int syncSec)
   {
      m_heartbeatIntervalSec = MathMax(1, heartbeatSec);
      m_commandIntervalSec   = MathMax(1, commandSec);
      m_syncIntervalSec      = MathMax(1, syncSec);
   }

   bool StartAll(void)
   {
      EventSetTimer(1);
      return true;
   }

   void StopAll(void)
   {
      EventKillTimer();
   }

   bool ShouldRunHeartbeat(const datetime lastRunAt) const
   {
      return (TimeCurrent() - lastRunAt >= m_heartbeatIntervalSec);
   }

   bool ShouldRunCommands(const datetime lastRunAt) const
   {
      return (TimeCurrent() - lastRunAt >= m_commandIntervalSec);
   }

   bool ShouldRunSync(const datetime lastRunAt) const
   {
      return (TimeCurrent() - lastRunAt >= m_syncIntervalSec);
   }
};

#endif
