# `/api/oauth/usage`

```
GET https://api.anthropic.com/api/oauth/usage?at_wall=1
Authorization: Bearer <claudeAiOauth.accessToken>
anthropic-beta: oauth-2025-04-20
```

`at_wall=1` reports a window that has hit its ceiling as `100` rather than
capping earlier. **Never send `skip_spend=1`** - it returns `spend` and
`extra_usage` as `null`, which drops the credits segment with no error.

## Token location

| Platform | Location |
| --- | --- |
| macOS | Keychain, generic password, service `Claude Code-credentials` |
| Linux, WSL | `~/.claude/.credentials.json` |

Both hold JSON with the token at `claudeAiOauth.accessToken`.

## Response

```jsonc
{
  "five_hour":  { "utilization": 82.0, "resets_at": "2031-01-04T18:00:00Z" },
  "seven_day":  { "utilization": 41.0, "resets_at": "2031-01-06T09:00:00Z" },
  "extra_usage": {
    "is_enabled": true,
    "monthly_limit": 50000,      // minor units
    "used_credits": 12500.0,
    "utilization": 25.0,
    "currency": "USD",
    "decimal_places": 2
  },
  "spend": {
    "used":  { "amount_minor": 12500, "currency": "USD", "exponent": 2 },
    "limit": { "amount_minor": 50000, "currency": "USD", "exponent": 2 },
    "percent": 25
  },
  "limits": [
    { "kind": "session",       "percent": 82, "scope": null },
    { "kind": "weekly_all",    "percent": 41, "scope": null },
    { "kind": "weekly_scoped", "percent": 57,
      "scope": { "model": { "display_name": "Fable" } } }
  ]
}
```

`utilization` here is already 0-100. It is **not** the same scale as the
`anthropic-ratelimit-unified-*-utilization` response headers Claude Code parses
internally, which are 0-1 fractions.

Windows that do not apply to the account come back `null`: `seven_day_opus`,
`seven_day_sonnet`, `seven_day_oauth_apps`, and others.

## Segment mapping

| Segment | Source |
| --- | --- |
| `5h` | `.five_hour.utilization` |
| `7d` | `.seven_day.utilization` |
| per-model | `.limits[] \| select(.kind=="weekly_scoped") \| .percent`, labelled from `.scope.model.display_name` |
| `credits` | `.extra_usage.utilization` |

Per-model segments are emitted for every `weekly_scoped` entry, so an account
with an Opus or Sonnet window gets those without a code change.

## What Claude Code puts in the status line JSON

The payload is built by hand and carries at most three windows:

```js
{ ...five_hour  && { five_hour:  { used_percentage: five_hour.utilization*100 } },
  ...seven_day  && { seven_day:  { used_percentage: seven_day.utilization*100 } },
  ...isGateway  && overage && { spend_limit: { used_percentage: overage.utilization*100 } } }
```

`spend_limit` is the overage window and appears only behind a Claude gateway, so
a normal subscription never sees it. Per-model windows exist internally as
`rate_limits.model_scoped[]` but are not passed through. `usage-segments.sh`
falls back to this payload only until the first fetch lands.
