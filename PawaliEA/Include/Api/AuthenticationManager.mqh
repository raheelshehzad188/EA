//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Authentication manager                      |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_API_AUTHENTICATION_MANAGER_MQH
#define PAWALI_EA_API_AUTHENTICATION_MANAGER_MQH

#include "../Interfaces/IAuthenticatable.mqh"
#include "ApiClient.mqh"
#include "../Enums/ApiEndpoints.mqh"
#include "../Utilities/JsonSerializer.mqh"
#include "../Utilities/StringUtils.mqh"
#include "../Utilities/TimeUtils.mqh"
#include "../Utilities/FileUtils.mqh"

class CPawaliAuthenticationManager : public IPawaliAuthenticatable
{
private:
   CPawaliApiClient  *m_client;
   CPawaliLogger     *m_logger;
   SPawaliApiConfig   m_config;
   SPawaliTokenBundle m_tokens;
   string             m_tokenCachePath;
   int                m_refreshCount;

   SPawaliAuthRequest BuildRequest(void) const
   {
      SPawaliAuthRequest request;
      request.licenseKey    = m_config.licenseKey;
      request.accountNumber = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
      request.eaVersion     = m_config.eaVersion;
      return request;
   }

   bool SaveTokenCache(void) const
   {
      if(!m_tokens.isValid)
         return false;
      return CPawaliFileUtils::WriteAllText(m_tokenCachePath,
                                            CPawaliJsonSerializer::SerializeTokenBundle(m_tokens));
   }

   bool LoadTokenCache(void)
   {
      string json = "";
      if(!CPawaliFileUtils::ReadAllText(m_tokenCachePath, json))
         return false;

      if(!CPawaliJsonSerializer::ParseTokenBundle(json, m_tokens))
         return false;

      return HasValidToken();
   }

   bool ApplyAuthResponse(const SPawaliHttpResponse &httpResponse,
                          SPawaliAuthResponse &response)
   {
      response.httpStatus = httpResponse.statusCode;
      response.success    = false;

      if(!CPawaliJsonSerializer::ParseAuthResponse(httpResponse.body, response))
      {
         response.message = (response.message != "" ?
                             response.message : httpResponse.errorMessage);
         return false;
      }

      m_tokens.accessToken  = response.accessToken;
      m_tokens.refreshToken = response.refreshToken;
      m_tokens.expiresAt    = response.expiresAt;
      m_tokens.isValid      = true;
      SaveTokenCache();
      return true;
   }

   bool IsExpiringSoon(void) const
   {
      if(!m_tokens.isValid || m_tokens.expiresAt <= 0)
         return false;

      const datetime refreshAt = m_tokens.expiresAt - m_config.tokenRefreshBufferSec;
      return (TimeCurrent() >= refreshAt);
   }

public:
   CPawaliAuthenticationManager(void) :
      m_client(NULL),
      m_logger(NULL),
      m_refreshCount(0)
   {
      m_tokens.isValid = false;
      m_tokenCachePath = "PawaliEA/Cache/tokens.json";
   }

   void Init(CPawaliApiClient *client,
             CPawaliLogger *logger,
             const SPawaliApiConfig &config)
   {
      m_client = client;
      m_logger = logger;
      m_config = config;
      CPawaliFileUtils::EnsureDirectory("PawaliEA/Cache");
      LoadTokenCache();
   }

   int GetRefreshCount(void) const { return m_refreshCount; }

   virtual bool Authenticate(SPawaliAuthResponse &response) override
   {
      if(m_client == NULL)
         return false;

      if(m_config.baseUrl == "" || m_config.licenseKey == "")
      {
         if(m_logger != NULL)
            m_logger.ApiError("Authentication credentials are incomplete. Require base URL and license key.");
         return false;
      }

      const SPawaliAuthRequest request = BuildRequest();
      if(request.accountNumber == "" || request.accountNumber == "0")
      {
         if(m_logger != NULL)
            m_logger.ApiError("Authentication credentials are incomplete. Account number unavailable.");
         return false;
      }

      const string payload = CPawaliJsonSerializer::SerializeAuthRequest(request);
      SPawaliHttpResponse httpResponse;

      if(!m_client.Send(PAWALI_HTTP_POST, PAWALI_API_AUTH, payload, "", httpResponse))
      {
         response.success    = false;
         response.httpStatus = httpResponse.statusCode;
         response.message    = httpResponse.errorMessage;
         return false;
      }

      const bool ok = ApplyAuthResponse(httpResponse, response);
      if(ok && m_logger != NULL)
         m_logger.ApiInfo("Authentication succeeded.");
      else if(m_logger != NULL)
         m_logger.ApiError(StringFormat("Authentication rejected: %s", response.message));
      return ok;
   }

   virtual bool RefreshToken(SPawaliAuthResponse &response) override
   {
      if(m_client == NULL)
         return false;

      if(m_tokens.refreshToken == "")
         return Authenticate(response);

      const string payload = CPawaliJsonSerializer::SerializeRefreshRequest(m_tokens.refreshToken);
      SPawaliHttpResponse httpResponse;

      if(!m_client.Send(PAWALI_HTTP_POST, PAWALI_API_AUTH_REFRESH, payload, "", httpResponse))
      {
         if(m_logger != NULL)
            m_logger.ApiWarn("Token refresh failed. Falling back to full authentication.");
         return Authenticate(response);
      }

      m_refreshCount++;
      const bool ok = ApplyAuthResponse(httpResponse, response);
      if(ok && m_logger != NULL)
         m_logger.ApiInfo(StringFormat("Token refreshed (#%d).", m_refreshCount));
      return ok;
   }

   virtual bool HasValidToken(void) const override
   {
      if(!m_tokens.isValid || m_tokens.accessToken == "")
         return false;

      if(m_tokens.expiresAt <= 0)
         return true;

      return !CPawaliTimeUtils::IsExpired(m_tokens.expiresAt);
   }

   virtual string GetAccessToken(void) const override
   {
      return m_tokens.accessToken;
   }

   void InvalidateToken(void)
   {
      m_tokens.isValid     = false;
      m_tokens.accessToken = "";
   }

   bool EnsureToken(SPawaliAuthResponse &response)
   {
      if(HasValidToken() && !IsExpiringSoon())
         return true;

      if(HasValidToken() && IsExpiringSoon())
      {
         if(m_logger != NULL)
            m_logger.ApiInfo("Access token expiring soon. Proactive refresh.");
         return RefreshToken(response);
      }

      if(m_logger != NULL)
         m_logger.ApiInfo("Access token missing or expired. Refreshing...");

      if(m_tokens.refreshToken != "")
         return RefreshToken(response);

      return Authenticate(response);
   }

   bool ExecuteAuthorizedRequest(const ENUM_PAWALI_HTTP_METHOD method,
                                 const string endpoint,
                                 const string payloadJson,
                                 const string idempotencyKey,
                                 SPawaliHttpResponse &response)
   {
      SPawaliAuthResponse authResponse;
      if(!EnsureToken(authResponse))
         return false;

      if(!m_client.SendWithIdempotency(method, endpoint, payloadJson,
                                       m_tokens.accessToken, idempotencyKey, response))
      {
         if(response.statusCode == 401)
         {
            InvalidateToken();
            if(!EnsureToken(authResponse))
               return false;

            return m_client.SendWithIdempotency(method, endpoint, payloadJson,
                                                m_tokens.accessToken, idempotencyKey, response);
         }
         return false;
      }

      if(m_client != NULL)
         m_client.ResetFailureCounter();
      return true;
   }
};

#endif
