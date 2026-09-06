---
name: statusline-usage-limits
description: Show Claude Code plan usage in the status line - the 5-hour session window, the weekly all-models window, each per-model weekly window (Fable, Opus, Sonnet), and the usage-credit balance - each coloured green, amber or red by how close it is to its limit. Use when someone asks to put usage, rate limits, quota, the weekly limit, the Fable limit, or credit spend in their status line, asks why their status line shows no usage or is missing the Fable or credits segment, or wants the numbers from /usage visible without opening /usage.
---

# Usage limits in the status line

Adds a line like this under the normal status line:

```
5h:82% | 7d:41% | fable:57% | credits:25%
```

Green below 70%, amber 70-89%, red 90% and above.

## Why this needs its own fetch

Claude Code hands the status line a `rate_limits` object holding only
`five_hour`, `seven_day`, and a `spend_limit` that appears solely for gateway
users. The per-model weekly windows and the credit balance are never in it, so
they are read from `/api/oauth/usage` instead. `references/endpoint.md` records
the response shape and the field-to-segment mapping.

The status line reads a cache and never calls the network, so the fetch cannot
delay a prompt render.

## Install

```bash
scripts/install.sh
```

With no status line configured, it writes one and registers it. With a status
line already present it prints the two lines to add and changes nothing, because
a hand-written status line offers no safe insertion point to guess at.

Requires `jq`, `curl`, and `python3`. Reads the OAuth token from the macOS
Keychain, or from `~/.claude/.credentials.json` on Linux and WSL.

## How it fits together

| File | Role |
| --- | --- |
| `scripts/usage-segments.sh` | Takes the status line JSON as its one argument, prints the coloured fragment, spawns a refresh when the cache ages past 120s. Prints nothing when no window is known. |
| `scripts/usage-refresh.sh` | Fetches `/api/oauth/usage` into `~/.claude/cache/usage.json`. Exits 0 on every failure so the last good numbers survive. |
| `scripts/install.sh` | Wires the first script into a status line. |

Call the fragment from any status line, in any language:

```bash
usage=$(~/.claude/skills/statusline-usage-limits/scripts/usage-segments.sh "$input")
[ -n "$usage" ] && printf '\n%s' "$usage"
```

## Tuning

Set these in the environment of the status line command:

| Variable | Default | Effect |
| --- | --- | --- |
| `USAGE_LIMITS_WARN` | `70` | Amber at or above this percent |
| `USAGE_LIMITS_CRIT` | `90` | Red at or above this percent |
| `USAGE_LIMITS_TTL` | `120` | Seconds before the cache is refetched |
| `USAGE_LIMITS_SEP` | `" \| "` | Text between segments |
| `USAGE_LIMITS_CACHE` | `~/.claude/cache/usage.json` | Cache location |

## When a segment is missing

Run the fetch in the foreground and read the error:

```bash
bash scripts/usage-refresh.sh && jq . ~/.claude/cache/usage.json
```

- **Every segment missing** - the token could not be read, or the fetch failed.
  Both cases exit 0 by design; the foreground run shows why.
- **Only `credits` missing** - `extra_usage` is `null`. Accounts without usage
  credits have no balance to show. Adding `skip_spend=1` to the request also
  nulls it, so check the URL has not picked that parameter up.
- **No per-model segment** - that account has no `weekly_scoped` entry in
  `limits[]`. Compare against `/usage`, which reads the same endpoint.
- **Numbers behind `/usage`** - expected, up to `USAGE_LIMITS_TTL` seconds.
