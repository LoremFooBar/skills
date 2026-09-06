# skills

Skills for [Claude Code](https://claude.com/claude-code).

| Skill | What it does |
| --- | --- |
| [statusline-usage-limits](plugins/statusline-usage-limits) | Puts your plan usage in the status line: the 5-hour window, the weekly window, each per-model weekly window, and your usage-credit balance — coloured by how close each is to its limit. |

## Install

```
/plugin marketplace add LoremFooBar/skills
/plugin install statusline-usage-limits@loremfoobar-skills
```

Then follow the skill's own setup step — for `statusline-usage-limits`, ask
Claude to "add usage limits to my status line", or run its `scripts/install.sh`.

<details>
<summary>Without plugins</summary>

Copy the skill directory into `~/.claude/skills/`:

```bash
git clone https://github.com/LoremFooBar/skills /tmp/lfb-skills
cp -R /tmp/lfb-skills/plugins/statusline-usage-limits/skills/statusline-usage-limits ~/.claude/skills/
```

Skills in `~/.claude/skills/` load in every project.
</details>

---

## statusline-usage-limits

```
Opus 5 (high) | ~/repos/api | main | ctx:31%
5h:82% | 7d:41% | fable:57% | credits:25%
```

Green below 70%, amber 70–89%, red at 90% and above.

### Why it exists

Claude Code gives a status line command a `rate_limits` object holding only
`five_hour`, `seven_day`, and a `spend_limit` that appears solely for gateway
users. The per-model weekly windows and the credit balance are never in it — you
can see them in `/usage`, but not from a status line.

This skill reads them from the same endpoint `/usage` uses, caches the result,
and renders the cache. The status line itself never touches the network, so
nothing is added to the time it takes a prompt to draw.

### Setup

```bash
plugins/statusline-usage-limits/skills/statusline-usage-limits/scripts/install.sh
```

With no status line configured, it writes one and registers it. With a status
line already present it prints the two lines to add and changes nothing — a
hand-written status line offers no safe insertion point to guess at.

To wire it in by hand, from any status line in any language:

```bash
usage=$(~/.claude/skills/statusline-usage-limits/scripts/usage-segments.sh "$input")
[ -n "$usage" ] && printf '\n%s' "$usage"
```

`$input` is the raw status line JSON. The script prints nothing when no window
is known, so an emptiness test is enough to drop the line.

### Credentials

The fetch needs your Claude OAuth token, the same one Claude Code already holds.
It is read at run time from the macOS Keychain (`Claude Code-credentials`), or
from `~/.claude/.credentials.json` on Linux and WSL. Nothing is stored, logged,
or sent anywhere except `api.anthropic.com`.

`scripts/usage-refresh.sh` is 40 lines. Read it before you run it.

### Requirements

`jq`, `curl`, `python3`, and a Claude subscription. API-key, Bedrock, and Vertex
users have no plan windows to show.

### Tuning

Set these in the environment of your status line command:

| Variable | Default | Effect |
| --- | --- | --- |
| `USAGE_LIMITS_WARN` | `70` | Amber at or above this percent |
| `USAGE_LIMITS_CRIT` | `90` | Red at or above this percent |
| `USAGE_LIMITS_TTL` | `120` | Seconds before the cache is refetched |
| `USAGE_LIMITS_SEP` | `" \| "` | Text between segments |
| `USAGE_LIMITS_CACHE` | `~/.claude/cache/usage.json` | Cache location |

### When a segment is missing

Run the fetch in the foreground and read the error:

```bash
~/.claude/skills/statusline-usage-limits/scripts/usage-refresh.sh
jq . ~/.claude/cache/usage.json
```

- **Everything missing** — the token could not be read, or the fetch failed.
  Both exit 0 by design so the status line keeps its last good numbers; the
  foreground run shows the reason.
- **Only `credits`** — accounts without usage credits have no balance to show.
- **No per-model segment** — that account has no per-model weekly window. Check
  against `/usage`, which reads the same endpoint.
- **Numbers behind `/usage`** — expected, by up to `USAGE_LIMITS_TTL` seconds.

The response shape and the field-to-segment mapping are in
[`references/endpoint.md`](plugins/statusline-usage-limits/skills/statusline-usage-limits/references/endpoint.md).

## Licence

MIT
