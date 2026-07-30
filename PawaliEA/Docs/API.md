# PawaliEA Laravel API Contract

Base URL configured via `InpApiBaseUrl`.

Authentication: `Authorization: Bearer {access_token}`

Content-Type: `application/json`

---

## POST /api/auth

Request:

```json
{
  "license_key": "string",
  "api_key": "string",
  "api_secret": "string",
  "terminal_id": "string",
  "account_number": "string",
  "broker": "string",
  "server": "string",
  "ea_version": "1.0.0"
}
```

Response:

```json
{
  "success": true,
  "access_token": "string",
  "refresh_token": "string",
  "expires_at": 1750000000,
  "expires_in": 3600,
  "message": "Authenticated"
}
```

---

## POST /api/auth/refresh

Request:

```json
{
  "refresh_token": "string"
}
```

Response: same shape as `/api/auth`.

---

## GET /api/settings

Response:

```json
{
  "version": 12,
  "trading_enabled": true,
  "buy_enabled": true,
  "sell_enabled": true,
  "risk_percent": 1.0,
  "max_spread_points": 30,
  "strategy_version": "1.2.0",
  "updated_at": 1750000000
}
```

---

## POST /api/heartbeat

Request fields match `SPawaliHeartbeatPayload` in `HeartbeatModels.mqh`.

---

## POST /api/trades

Request fields match `SPawaliTradeRecord` in `TradeModels.mqh`.

Idempotency: `client_trade_id`

---

## POST /api/decisions

Request fields match `SPawaliDecisionRecord` in `DecisionModels.mqh`.

Idempotency: `client_decision_id`

---

## GET /api/commands

Response example:

```json
{
  "data": [
    {
      "uuid": "550e8400-e29b-41d4-a716-446655440000",
      "type": "FORCE_SYNC",
      "payload": {}
    }
  ]
}
```

Supported `type` values:

- `PAUSE_TRADING`
- `RESUME_TRADING`
- `UPDATE_SETTINGS`
- `FORCE_SYNC`
- `RESTART_EA`
- `CLOSE_ALL`
- `CLOSE_BUY`
- `CLOSE_SELL`
- `DISABLE_BUY`
- `DISABLE_SELL`
- `REDUCE_RISK`

---

## POST /api/commands/{uuid}/complete

Request:

```json
{
  "success": true,
  "message": "OK"
}
```

---

## Error Handling

| HTTP Code | EA Behavior |
|-----------|-------------|
| 2xx | Success |
| 401 | Stop retry chain, refresh token |
| 4xx/5xx | Retry with backoff, queue if exhausted |
| Network error | Offline queue + continue local operation |

---

## MT5 WebRequest Setup

Add to allowed URLs in terminal settings:

```
https://api.pawali.local
```

Replace with your production Laravel domain.
