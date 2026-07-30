# PawaliEA Enterprise

Production-grade MT5 Expert Advisor shell for Laravel-backed remote control, synchronization, and enterprise reliability.

## Scope (Phase 1)

- Modular OOP architecture
- Laravel REST API integration
- Bearer token authentication with refresh
- Heartbeat telemetry
- Remote command handling
- Settings hot-reload (no EA restart)
- Offline queue with idempotency
- Multi-channel file logging
- On-chart debug panel

**Not included in this phase:** trading strategy logic, AI decision engine.

## Folder Structure

```
PawaliEA/
├── PawaliEA.mq5
├── Docs/
│   ├── ARCHITECTURE.md
│   └── API.md
└── Include/
    ├── Api/
    ├── Core/
    ├── Enums/
    ├── Indicators/
    ├── Interfaces/
    ├── Logs/
    ├── Models/
    ├── Trading/
    └── Utilities/
```

## Installation

1. Copy the `PawaliEA` folder into `MQL5/Experts/`.
2. Ensure include paths resolve relative to `PawaliEA.mq5`.
3. In MT5: **Tools → Options → Expert Advisors → Allow WebRequest**
4. Add your Laravel API domain to the allowed URL list.
5. Attach `PawaliEA.mq5` to a chart and configure inputs.

## Startup Sequence

1. Validate license key locally
2. `POST /api/auth` → receive bearer token
3. `GET /api/settings` → download remote settings
4. Start timers: heartbeat (60s), commands (15s), sync (30s)
5. Start trading engine placeholder

## Logs

Written to terminal common files:

- `PawaliEA/Logs/Expert.log`
- `PawaliEA/Logs/API.log`
- `PawaliEA/Logs/Trade.log`
- `PawaliEA/Logs/Error.log`
- `PawaliEA/Logs/Performance.log`

## Offline Mode

When the API is unavailable:

- EA continues running
- Requests are persisted in `PawaliEA/Queue/offline_queue.txt`
- Idempotency keys prevent duplicate trade/decision uploads
- Queue replay runs on each sync cycle after token refresh

## Remote Commands

| Command | Effect |
|---------|--------|
| `PAUSE_TRADING` | Pause trading engine |
| `RESUME_TRADING` | Resume trading engine |
| `UPDATE_SETTINGS` | Force settings download |
| `FORCE_SYNC` | Force settings + sync cycle |
| `RESTART_EA` | Flag restart (handled by host) |
| `CLOSE_ALL` | Acknowledged (trading phase) |
| `CLOSE_BUY` | Acknowledged (trading phase) |
| `CLOSE_SELL` | Acknowledged (trading phase) |
| `DISABLE_BUY` | Disable buy side |
| `DISABLE_SELL` | Disable sell side |
| `REDUCE_RISK` | Halve configured risk |

## Version

- EA: `1.0.0`
- Strategy: input `InpStrategyVersion`
