//+------------------------------------------------------------------+
//| PawaliEA Enterprise - HTTP API client                             |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_API_API_CLIENT_MQH
#define PAWALI_EA_API_API_CLIENT_MQH

#include "../Interfaces/IApiTransport.mqh"
#include "../Models/ApiConfig.mqh"
#include "../Enums/ConnectionStatus.mqh"
#include "../Logs/Logger.mqh"

class CPawaliApiClient : public IPawaliApiTransport
{
private:
   SPawaliApiConfig       m_config;
   CPawaliLogger         *m_logger;
   ENUM_PAWALI_API_STATUS m_status;
   SPawaliHttpResponse    m_lastResponse;
   int                    m_consecutiveFailures;

   string BuildUrl(const string endpoint) const
   {
      string base = m_config.baseUrl;
      if(StringLen(base) > 0 && StringGetCharacter(base, StringLen(base) - 1) == '/')
         base = StringSubstr(base, 0, StringLen(base) - 1);
      return base + endpoint;
   }

   string BuildHeaders(const string bearerToken, const string idempotencyKey) const
   {
      string headers = "Content-Type: application/json\r\n";
      headers += "Accept: application/json\r\n";
      headers += "User-Agent: PawaliEA/" + m_config.eaVersion + "\r\n";
      if(bearerToken != "")
         headers += "Authorization: Bearer " + bearerToken + "\r\n";
      if(idempotencyKey != "")
         headers += "Idempotency-Key: " + idempotencyKey + "\r\n";
      return headers;
   }

   bool ShouldRetry(const SPawaliHttpResponse &response) const
   {
      if(response.statusCode == -1)
         return true;
      if(response.statusCode == 408 || response.statusCode == 429)
         return true;
      if(response.statusCode >= 500)
         return true;
      return false;
   }

   bool ExecuteOnce(const ENUM_PAWALI_HTTP_METHOD method,
                    const string endpoint,
                    const string payloadJson,
                    const string bearerToken,
                    const string idempotencyKey,
                    SPawaliHttpResponse &response) const
   {
      response.success      = false;
      response.statusCode   = -1;
      response.body         = "";
      response.errorMessage = "";
      response.latencyMs    = 0;

      const string url = BuildUrl(endpoint);
      string headers   = BuildHeaders(bearerToken, idempotencyKey);
      char requestData[];
      char responseData[];
      string responseHeaders;

      if(payloadJson != "")
         StringToCharArray(payloadJson, requestData, 0, WHOLE_ARRAY, CP_UTF8);
      else
         ArrayResize(requestData, 0);

      const uint startMs = GetTickCount();
      ResetLastError();

      int httpCode = -1;
      if(method == PAWALI_HTTP_GET)
         httpCode = WebRequest("GET", url, headers, m_config.timeoutMs, requestData, responseData, responseHeaders);
      else
         httpCode = WebRequest("POST", url, headers, m_config.timeoutMs, requestData, responseData, responseHeaders);

      response.latencyMs  = (int)(GetTickCount() - startMs);
      response.statusCode = httpCode;

      if(httpCode == -1)
      {
         response.errorMessage = StringFormat("WebRequest failed. Error=%d", GetLastError());
         return false;
      }

      response.body = CharArrayToString(responseData, 0, WHOLE_ARRAY, CP_UTF8);
      response.success = (httpCode >= 200 && httpCode < 300);
      if(!response.success)
         response.errorMessage = StringFormat("HTTP %d: %s", httpCode, response.body);

      return response.success;
   }

public:
   CPawaliApiClient(void) :
      m_logger(NULL),
      m_status(PAWALI_API_IDLE),
      m_consecutiveFailures(0)
   {
      m_lastResponse.success = false;
   }

   void Init(const SPawaliApiConfig &config, CPawaliLogger *logger)
   {
      m_config = config;
      m_logger = logger;
   }

   ENUM_PAWALI_API_STATUS GetStatus(void) const { return m_status; }

   SPawaliHttpResponse GetLastResponse(void) const
   {
      return m_lastResponse;
   }

   int GetConsecutiveFailures(void) const
   {
      return m_consecutiveFailures;
   }

   void ResetFailureCounter(void)
   {
      m_consecutiveFailures = 0;
   }

   virtual bool Send(const ENUM_PAWALI_HTTP_METHOD method,
                     const string endpoint,
                     const string payloadJson,
                     const string bearerToken,
                     SPawaliHttpResponse &response) override
   {
      return SendWithIdempotency(method, endpoint, payloadJson, bearerToken, "", response);
   }

   bool SendWithIdempotency(const ENUM_PAWALI_HTTP_METHOD method,
                            const string endpoint,
                            const string payloadJson,
                            const string bearerToken,
                            const string idempotencyKey,
                            SPawaliHttpResponse &response)
   {
      m_status = PAWALI_API_BUSY;

      for(int attempt = 0; attempt <= m_config.maxRetries; attempt++)
      {
         if(attempt > 0)
         {
            m_status = PAWALI_API_RETRYING;
            if(m_logger != NULL)
               m_logger.ApiWarn(StringFormat("Retry %s attempt %d/%d",
                                             endpoint, attempt + 1, m_config.maxRetries + 1));
            Sleep(m_config.retryDelayMs * attempt);
         }

         if(ExecuteOnce(method, endpoint, payloadJson, bearerToken, idempotencyKey, response))
         {
            m_lastResponse         = response;
            m_status               = PAWALI_API_IDLE;
            m_consecutiveFailures  = 0;
            if(m_logger != NULL)
               m_logger.Performance(StringFormat("API %s %dms", endpoint, response.latencyMs));
            return true;
         }

         m_lastResponse = response;

         if(response.statusCode == 401)
            break;

         if(!ShouldRetry(response))
            break;
      }

      m_status = PAWALI_API_ERROR;
      m_consecutiveFailures++;
      if(m_logger != NULL)
         m_logger.ApiError(StringFormat("%s failed: %s", endpoint, response.errorMessage));
      return false;
   }
};

#endif
