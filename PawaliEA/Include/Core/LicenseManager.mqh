//+------------------------------------------------------------------+
//| PawaliEA Enterprise - License manager                             |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_CORE_LICENSE_MANAGER_MQH
#define PAWALI_EA_CORE_LICENSE_MANAGER_MQH

#include "../Models/LicenseModels.mqh"
#include "../Models/ApiConfig.mqh"
#include "../Logs/Logger.mqh"
#include "../Utilities/TimeUtils.mqh"

class CPawaliLicenseManager
{
private:
   SPawaliLicenseInfo m_license;
   CPawaliLogger     *m_logger;

public:
   CPawaliLicenseManager(void) : m_logger(NULL)
   {
      m_license.status = PAWALI_LICENSE_UNKNOWN;
      m_license.isValid = false;
   }

   void Init(CPawaliLogger *logger, const SPawaliApiConfig &config)
   {
      m_logger = logger;
      m_license.licenseKey = config.licenseKey;
   }

   bool Validate(void)
   {
      if(m_license.licenseKey == "")
      {
         m_license.status  = PAWALI_LICENSE_INVALID;
         m_license.isValid = false;
         m_license.message = "License key is empty.";
         if(m_logger != NULL)
            m_logger.Error(m_license.message);
         return false;
      }

      // Production hook: server-side validation occurs during /api/auth.
      m_license.status   = PAWALI_LICENSE_VALID;
      m_license.isValid  = true;
      m_license.expiresAt = CPawaliTimeUtils::AddSeconds(TimeCurrent(), 86400 * 365);
      m_license.message  = "License validated locally.";
      if(m_logger != NULL)
         m_logger.ExpertInfo("License validation passed.");
      return true;
   }

   void ApplyServerLicenseState(const bool authSuccess, const datetime expiresAt)
   {
      if(!authSuccess)
      {
         m_license.status  = PAWALI_LICENSE_INVALID;
         m_license.isValid = false;
         return;
      }

      m_license.status    = PAWALI_LICENSE_VALID;
      m_license.isValid   = true;
      m_license.expiresAt = expiresAt;
   }

   SPawaliLicenseInfo GetLicenseCopy(void) const
   {
      return m_license;
   }
};

#endif
