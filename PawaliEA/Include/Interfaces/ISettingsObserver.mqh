//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Settings observer interface                 |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_INTERFACES_I_SETTINGS_OBSERVER_MQH
#define PAWALI_EA_INTERFACES_I_SETTINGS_OBSERVER_MQH

#include "../Models/SettingsModels.mqh"

class IPawaliSettingsObserver
{
public:
   virtual void OnSettingsUpdated(const SPawaliRemoteSettings &settings) = 0;
};

#endif
