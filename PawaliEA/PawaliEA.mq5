//+------------------------------------------------------------------+
//|                                                   PawaliEA.mq5    |
//|                        PawaliEA Enterprise - Production Shell   |
//|                                                                  |
//| Architecture-only release. No trading logic. No AI.              |
//+------------------------------------------------------------------+
#property copyright "PawaliEA Enterprise"
#property version   "1.00"

#include "Include/Core/Application.mqh"

// MT5 requires a single bootstrap instance for event handlers.
class CPawaliBootstrap
{
private:
   CPawaliApplication m_application;

public:
   int OnInit(void)
   {
      return m_application.Initialize();
   }

   void OnDeinit(const int reason)
   {
      m_application.Shutdown(reason);
   }

   void OnTick(void)
   {
      m_application.ProcessTick();
   }

   void OnTimer(void)
   {
      m_application.ProcessTimer();
   }
};

CPawaliBootstrap PawaliBootstrap;

int OnInit(void)
{
   return PawaliBootstrap.OnInit();
}

void OnDeinit(const int reason)
{
   PawaliBootstrap.OnDeinit(reason);
}

void OnTick(void)
{
   PawaliBootstrap.OnTick();
}

void OnTimer(void)
{
   PawaliBootstrap.OnTimer();
}

//+------------------------------------------------------------------+
