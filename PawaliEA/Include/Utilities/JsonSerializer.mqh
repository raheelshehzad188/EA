//+------------------------------------------------------------------+
//| PawaliEA Enterprise - Lightweight JSON serializer                 |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_UTILITIES_JSON_SERIALIZER_MQH
#define PAWALI_EA_UTILITIES_JSON_SERIALIZER_MQH

#include "../Models/AuthModels.mqh"
#include "../Models/SettingsModels.mqh"
#include "../Models/HeartbeatModels.mqh"
#include "../Models/TradeModels.mqh"
#include "../Models/DecisionModels.mqh"
#include "../Models/CommandModels.mqh"
#include "../Models/QueueModels.mqh"
#include "../Utilities/StringUtils.mqh"

class CPawaliJsonSerializer
{
public:
   static string SerializeAuthRequest(const SPawaliAuthRequest &request)
   {
      return StringFormat(
         "{\"license_key\":\"%s\",\"api_key\":\"%s\",\"api_secret\":\"%s\","
         "\"terminal_id\":\"%s\",\"account_number\":\"%s\",\"broker\":\"%s\","
         "\"server\":\"%s\",\"ea_version\":\"%s\"}",
         CPawaliStringUtils::EscapeJson(request.licenseKey),
         CPawaliStringUtils::EscapeJson(request.apiKey),
         CPawaliStringUtils::EscapeJson(request.apiSecret),
         CPawaliStringUtils::EscapeJson(request.terminalId),
         CPawaliStringUtils::EscapeJson(request.accountNumber),
         CPawaliStringUtils::EscapeJson(request.broker),
         CPawaliStringUtils::EscapeJson(request.server),
         CPawaliStringUtils::EscapeJson(request.eaVersion));
   }

   static string SerializeRefreshRequest(const string refreshToken)
   {
      return StringFormat("{\"refresh_token\":\"%s\"}",
                          CPawaliStringUtils::EscapeJson(refreshToken));
   }

   static bool ParseAuthResponse(const string json, SPawaliAuthResponse &response)
   {
      response.success      = false;
      response.accessToken  = "";
      response.refreshToken = "";
      response.message      = "";
      response.expiresAt    = 0;
      response.httpStatus   = 0;

      string source = ResolvePayload(json);
      response.success      = ExtractBool(source, "success");
      response.accessToken  = ExtractString(source, "access_token");
      response.refreshToken = ExtractString(source, "refresh_token");
      response.message      = ExtractString(source, "message");
      response.expiresAt    = (datetime)ExtractLong(source, "expires_at");

      if(response.expiresAt <= 0)
      {
         const long expiresIn = ExtractLong(source, "expires_in");
         if(expiresIn > 0)
            response.expiresAt = TimeCurrent() + (datetime)expiresIn;
      }

      if(response.accessToken == "")
         response.accessToken = ExtractString(source, "token");

      return (response.success && response.accessToken != "");
   }

   static bool ParseSettings(const string json, SPawaliRemoteSettings &settings)
   {
      string source = ResolvePayload(json);
      if(TryParseSettingsObject(source, settings))
         return true;

      const string nested = ExtractNestedObject(json, "data");
      if(nested != "" && TryParseSettingsObject(nested, settings))
         return true;

      return false;
   }

   static bool TryParseSettingsObject(const string json, SPawaliRemoteSettings &settings)
   {
      settings.version           = (int)ExtractLong(json, "version");
      settings.tradingEnabled    = ExtractBool(json, "trading_enabled");
      settings.buyEnabled        = ExtractBool(json, "buy_enabled");
      settings.sellEnabled       = ExtractBool(json, "sell_enabled");
      settings.riskPercent       = ExtractDouble(json, "risk_percent");
      settings.maxSpreadPoints   = (int)ExtractLong(json, "max_spread_points");
      settings.strategyVersion   = ExtractString(json, "strategy_version");
      settings.updatedAt         = (datetime)ExtractLong(json, "updated_at");
      settings.isLoaded          = (settings.version > 0);
      return settings.isLoaded;
   }

   static string SerializeHeartbeat(const SPawaliHeartbeatPayload &payload)
   {
      return StringFormat(
         "{\"balance\":%.2f,\"equity\":%.2f,\"margin\":%.2f,\"free_margin\":%.2f,"
         "\"floating_profit\":%.2f,\"current_drawdown\":%.4f,\"broker\":\"%s\","
         "\"server\":\"%s\",\"ea_version\":\"%s\",\"mt5_build\":%d,\"magic_number\":%I64u,"
         "\"terminal_build\":%d,\"spread\":%.1f,\"ping_ms\":%d,\"cpu_usage\":%.2f,"
         "\"ram_usage\":%.2f,\"strategy_version\":\"%s\",\"current_symbol\":\"%s\","
         "\"open_trades\":%d,\"sent_at\":\"%s\"}",
         payload.balance,
         payload.equity,
         payload.margin,
         payload.freeMargin,
         payload.floatingProfit,
         payload.currentDrawdown,
         CPawaliStringUtils::EscapeJson(payload.broker),
         CPawaliStringUtils::EscapeJson(payload.server),
         CPawaliStringUtils::EscapeJson(payload.eaVersion),
         payload.mt5Build,
         payload.magicNumber,
         payload.terminalBuild,
         payload.spread,
         payload.pingMs,
         payload.cpuUsage,
         payload.ramUsage,
         CPawaliStringUtils::EscapeJson(payload.strategyVersion),
         CPawaliStringUtils::EscapeJson(payload.currentSymbol),
         payload.openTrades,
         CPawaliStringUtils::EscapeJson(TimeToString(payload.sentAt, TIME_DATE | TIME_SECONDS)));
   }

   static string SerializeTrade(const SPawaliTradeRecord &trade)
   {
      return StringFormat(
         "{\"client_trade_id\":\"%s\",\"ticket\":\"%s\",\"symbol\":\"%s\","
         "\"direction\":\"%s\",\"volume\":%.2f,\"entry_price\":%.5f,\"exit_price\":%.5f,"
         "\"stop_loss\":%.5f,\"take_profit\":%.5f,\"profit\":%.2f,"
         "\"opened_at\":\"%s\",\"closed_at\":\"%s\",\"comment\":\"%s\"}",
         CPawaliStringUtils::EscapeJson(trade.clientTradeId),
         CPawaliStringUtils::EscapeJson(trade.ticket),
         CPawaliStringUtils::EscapeJson(trade.symbol),
         CPawaliStringUtils::EscapeJson(trade.direction),
         trade.volume,
         trade.entryPrice,
         trade.exitPrice,
         trade.stopLoss,
         trade.takeProfit,
         trade.profit,
         CPawaliStringUtils::EscapeJson(TimeToString(trade.openedAt, TIME_DATE | TIME_SECONDS)),
         CPawaliStringUtils::EscapeJson(TimeToString(trade.closedAt, TIME_DATE | TIME_SECONDS)),
         CPawaliStringUtils::EscapeJson(trade.comment));
   }

   static string SerializeDecision(const SPawaliDecisionRecord &decision)
   {
      return StringFormat(
         "{\"client_decision_id\":\"%s\",\"symbol\":\"%s\",\"action\":\"%s\","
         "\"reason\":\"%s\",\"decided_at\":\"%s\",\"payload\":%s}",
         CPawaliStringUtils::EscapeJson(decision.clientDecisionId),
         CPawaliStringUtils::EscapeJson(decision.symbol),
         CPawaliStringUtils::EscapeJson(decision.action),
         CPawaliStringUtils::EscapeJson(decision.reason),
         CPawaliStringUtils::EscapeJson(TimeToString(decision.decidedAt, TIME_DATE | TIME_SECONDS)),
         (decision.payloadJson == "" ? "{}" : decision.payloadJson));
   }

   static string SerializeCommandComplete(const SPawaliCommandResult &result)
   {
      return StringFormat("{\"success\":%s,\"message\":\"%s\"}",
                          (result.success ? "true" : "false"),
                          CPawaliStringUtils::EscapeJson(result.message));
   }

   static string SerializeQueueItem(const SPawaliQueueItem &item)
   {
      return StringFormat(
         "{\"id\":\"%s\",\"type\":%d,\"method\":%d,\"endpoint\":\"%s\","
         "\"payload_text\":\"%s\",\"idempotency_key\":\"%s\",\"attempts\":%d,"
         "\"created_at\":%I64d,\"next_retry_at\":%I64d}",
         CPawaliStringUtils::EscapeJson(item.id),
         (int)item.type,
         (int)item.method,
         CPawaliStringUtils::EscapeJson(item.endpoint),
         CPawaliStringUtils::EscapeJson(item.payloadJson),
         CPawaliStringUtils::EscapeJson(item.idempotencyKey),
         item.attempts,
         (long)item.createdAt,
         (long)item.nextRetryAt);
   }

   static bool ParseQueueItem(const string json, SPawaliQueueItem &item)
   {
      item.id             = ExtractString(json, "id");
      item.type           = (ENUM_PAWALI_QUEUE_ITEM_TYPE)ExtractLong(json, "type");
      item.method         = (ENUM_PAWALI_HTTP_METHOD)ExtractLong(json, "method");
      item.endpoint       = ExtractString(json, "endpoint");
      item.payloadJson    = ExtractString(json, "payload_text");
      item.idempotencyKey = ExtractString(json, "idempotency_key");
      item.attempts       = (int)ExtractLong(json, "attempts");
      item.createdAt      = (datetime)ExtractLong(json, "created_at");
      item.nextRetryAt    = (datetime)ExtractLong(json, "next_retry_at");
      return (item.id != "" && item.endpoint != "");
   }

   static bool ParseCommandArray(const string json, SPawaliRemoteCommand &commands[])
   {
      ArrayResize(commands, 0);
      string source = json;
      const string nested = ExtractNestedArray(json, "data");
      if(nested != "")
         source = nested;

      int cursor = 0;
      while(true)
      {
         const int uuidPos = StringFind(source, "\"uuid\"", cursor);
         if(uuidPos < 0)
            break;

         const int typePos = StringFind(source, "\"type\"", uuidPos);
         if(typePos < 0)
            break;

         SPawaliRemoteCommand item;
         item.uuid        = ExtractStringFrom(source, uuidPos, "uuid");
         item.type        = PawaliCommandFromString(ExtractStringFrom(source, typePos, "type"));
         item.payloadJson = ExtractObjectFrom(source, typePos, "payload");
         item.receivedAt  = TimeCurrent();
         item.completed   = false;

         if(item.uuid == "")
            break;

         const int index = ArraySize(commands);
         ArrayResize(commands, index + 1);
         commands[index] = item;
         cursor = typePos + 6;
      }
      return true;
   }

   static string SerializeTokenBundle(const SPawaliTokenBundle &tokens)
   {
      return StringFormat(
         "{\"access_token\":\"%s\",\"refresh_token\":\"%s\",\"expires_at\":%I64d}",
         CPawaliStringUtils::EscapeJson(tokens.accessToken),
         CPawaliStringUtils::EscapeJson(tokens.refreshToken),
         (long)tokens.expiresAt);
   }

   static bool ParseTokenBundle(const string json, SPawaliTokenBundle &tokens)
   {
      tokens.accessToken  = ExtractString(json, "access_token");
      tokens.refreshToken = ExtractString(json, "refresh_token");
      tokens.expiresAt    = (datetime)ExtractLong(json, "expires_at");
      tokens.isValid      = (tokens.accessToken != "");
      return tokens.isValid;
   }

private:
   static string ResolvePayload(const string json)
   {
      if(ExtractString(json, "access_token") != "" ||
         ExtractString(json, "token") != "" ||
         ExtractLong(json, "version") > 0)
         return json;

      const string nested = ExtractNestedObject(json, "data");
      if(nested != "")
         return nested;
      return json;
   }

   static string ExtractNestedObject(const string json, const string key)
   {
      const string marker = "\"" + key + "\":";
      const int pos = StringFind(json, marker);
      if(pos < 0)
         return "";

      int start = StringFind(json, "{", pos);
      if(start < 0)
         return "";
      return ExtractBalanced(json, start, '{', '}');
   }

   static string ExtractNestedArray(const string json, const string key)
   {
      const string marker = "\"" + key + "\":";
      const int pos = StringFind(json, marker);
      if(pos < 0)
         return "";

      int start = StringFind(json, "[", pos);
      if(start < 0)
         return "";
      return ExtractBalanced(json, start, '[', ']');
   }

   static string ExtractBalanced(const string json, const int start,
                                 const ushort openChar, const ushort closeChar)
   {
      int depth = 0;
      for(int i = start; i < StringLen(json); i++)
      {
         const ushort ch = StringGetCharacter(json, i);
         if(ch == openChar)
            depth++;
         else if(ch == closeChar)
         {
            depth--;
            if(depth == 0)
               return StringSubstr(json, start, i - start + 1);
         }
      }
      return "";
   }

   static string ExtractObjectFrom(const string json, const int startPos, const string key)
   {
      const string marker = "\"" + key + "\":";
      const int pos = StringFind(json, marker, startPos);
      if(pos < 0)
         return "{}";

      int cursor = pos + StringLen(marker);
      while(cursor < StringLen(json) && StringGetCharacter(json, cursor) == ' ')
         cursor++;

      if(StringGetCharacter(json, cursor) == '{')
         return ExtractBalanced(json, cursor, '{', '}');
      return "{}";
   }

   static string ExtractString(const string json, const string key)
   {
      return ExtractStringFrom(json, 0, key);
   }

   static string ExtractStringFrom(const string json, const int startPos, const string key)
   {
      const string token = "\"" + key + "\":";
      const int pos = StringFind(json, token, startPos);
      if(pos < 0)
         return "";

      int valueStart = pos + StringLen(token);
      while(valueStart < StringLen(json) && StringGetCharacter(json, valueStart) == ' ')
         valueStart++;

      if(StringGetCharacter(json, valueStart) == '"')
      {
         valueStart++;
         const int valueEnd = StringFind(json, "\"", valueStart);
         if(valueEnd < 0)
            return "";
         return StringSubstr(json, valueStart, valueEnd - valueStart);
      }

      const int comma = StringFind(json, ",", valueStart);
      const int brace = StringFind(json, "}", valueStart);
      int valueEnd = comma;
      if(valueEnd < 0 || (brace >= 0 && brace < valueEnd))
         valueEnd = brace;
      if(valueEnd < 0)
         valueEnd = StringLen(json);

      return CPawaliStringUtils::Trim(StringSubstr(json, valueStart, valueEnd - valueStart));
   }

   static double ExtractDouble(const string json, const string key)
   {
      return StringToDouble(ExtractString(json, key));
   }

   static long ExtractLong(const string json, const string key)
   {
      return (long)StringToInteger(ExtractString(json, key));
   }

   static bool ExtractBool(const string json, const string key)
   {
      const string value = ExtractString(json, key);
      return (value == "true" || value == "1");
   }
};

#endif
