# skills

Skills for [Claude Code](https://claude.com/claude-code).

| Skill | What it does |
| --- | --- |
| [statusline-usage-limits](plugins/lorem-foo-skills/skills/statusline-usage-limits) | Puts your plan usage in the status line: the 5-hour window, the weekly window, each per-model weekly window, and your usage-credit balance — coloured by how close each is to its limit. |
| [quota-guarded-stages](plugins/lorem-foo-skills/skills/quota-guarded-stages) | Runs a queue of expensive stages (plugin evals, batch jobs) with a guard in front of each: pauses when the 5-hour window is nearly full and resumes after it resets, stops when a weekly window crosses its threshold, and continues an interrupted queue where it left off. |

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

The skill contributes one line, appended below whatever your status line already
prints:

```
5h:82% | 7d:41% | fable:57% | credits:25%
```

Green below 70%, amber 70–89%, red at 90% and above.

`5h` is the 5-hour session window, `7d` the weekly all-models window, `fable`
a per-model weekly window (you get one segment per window your plan has), and
`credits` your usage-credit balance.

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

With a status line already present, it prints the two lines to add and changes
nothing — a hand-written status line offers no safe insertion point to guess at.

With no status line configured, it writes a plain one so there is something to
attach to, giving you both rows:

```
Opus 5 | ~/repos/api | ctx:31%
5h:82% | 7d:41% | fable:57% | credits:25%
```

Only the second row comes from this skill. Replace the first with your own.

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

---

## quota-guarded-stages

For work that is too token-hungry to run in one go. Put the stages in a queue
file, one shell command per line, and start it detached:

```bash
S=~/.claude/plugins/cache/loremfoobar-skills/lorem-foo-skills/*/skills/quota-guarded-stages/scripts
nohup $S/run-queue.sh work.queue > work.log 2>&1 &
```

Before each stage the guard reads the same endpoint `/usage` reads. Defaults:
pause at 90% of the 5-hour window and resume when it is back at 5% or below,
re-checking every 30 minutes; stop for good at 85% of the weekly or any
per-model window. Finished stages are recorded in `work.queue.done`, so running
the same command again continues from the first unfinished stage. Thresholds
are environment variables (`QUOTA_PAUSE_5H`, `QUOTA_RESUME_5H`,
`QUOTA_STOP_WEEKLY`, `QUOTA_CHECK_INTERVAL`, `QUOTA_MODEL`); the skill's
`SKILL.md` lists them and tells Claude how to size stages and report progress.
