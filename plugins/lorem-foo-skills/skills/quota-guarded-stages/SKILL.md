---
name: quota-guarded-stages
description: Run a queue of expensive stages (plugin evals, batch jobs, long scripts) without blowing through Claude plan limits. Checks the 5-hour, weekly and per-model usage windows before every stage, pauses when the 5-hour window is nearly full and resumes when it resets, stops for good when a weekly window crosses its threshold, and resumes an interrupted queue from where it stopped. Use when a task is "very token hungry", needs to run "over a longer period", must "stop when the limit reaches X%", or when the user asks to watch quota, rate limits or usage while something long runs.
---

# Quota-guarded stages

Long agentic work (eval rounds, batch runs, migrations that call Claude) burns
plan quota in bursts. This skill splits the work into stages and puts a guard
in front of each one that reads the same usage endpoint `/usage` reads.

## Rules the guard enforces

| Window | Default | Behaviour |
| --- | --- | --- |
| 5-hour | pause at 90%, resume at 5% or below | Wait, re-check every 30 minutes, then continue. |
| Weekly, all models | stop at 85% | Write a STOP marker and exit 3. Nothing else runs. |
| Weekly, per model (Fable, Opus, ...) | stop at 85% | Same as above; the highest per-model window counts. |

The guard checks between stages, never inside one, because most stages cannot
be paused without losing their result. Size stages so one of them cannot
overshoot the limit on its own: measure how far one stage moves the 5-hour
window (an eval stage of 4 to 6 agents moved it about 40 points) and set the
pause threshold with that margin in mind.

**The numbers above are defaults.** When the user states their own ("stop at
80%", "pause the 5-hour window at 95%", "only watch Fable"), pass them as
environment variables on the launch command and repeat them back in the reply,
so the user sees which limits the guard is actually enforcing:

```
QUOTA_PAUSE_5H=95 QUOTA_STOP_WEEKLY=80 QUOTA_MODEL=Fable nohup <skill>/scripts/run-queue.sh work.queue > work.log 2>&1 &
```

Thresholds and timing are environment variables read by every script:

| Variable | Default | Meaning |
| --- | --- | --- |
| `QUOTA_PAUSE_5H` | `90` | Pause when the 5-hour window is at or above this percent |
| `QUOTA_RESUME_5H` | `5` | Resume once it is at or below this percent |
| `QUOTA_STOP_WEEKLY` | `85` | Stop when the weekly or any per-model window reaches this |
| `QUOTA_STOP_7D`, `QUOTA_STOP_MODEL` | same as `QUOTA_STOP_WEEKLY` | Set the two weekly stops separately when the user gives different numbers |
| `QUOTA_CHECK_INTERVAL` | `1800` | Seconds between checks while paused |
| `QUOTA_MODEL` | (all) | Watch one per-model window only, by display name (`Fable`) |
| `QUOTA_STATE_DIR` | `~/.claude/quota-guard` | Where the STOP marker, the log and the cached reading live |
| `QUOTA_CACHE_TTL` | `60` | Seconds a reading is reused before fetching again (the endpoint answers bursts with 429) |
| `QUOTA_STALE_MAX` | `7200` | How old a cached reading may be when a fetch fails; older means "unknown" |

## Scripts

| Script | Role |
| --- | --- |
| `scripts/usage-check.sh` | Prints `5h=NN 7d=NN fable=NN ... 5h_resets_at=<utc>` and exits 0 (go), 2 (pause), 3 (stop) or 4 (unknown). Reads the OAuth token from the macOS Keychain or `~/.claude/.credentials.json`; `QUOTA_USAGE_JSON=<file>` bypasses the network for tests. |
| `scripts/guard.sh <command...>` | Runs the check, waits through a pause, then runs the command. Exit 3 means stopped by quota; otherwise the command's exit code. |
| `scripts/run-queue.sh <queue-file>` | Runs each line of a queue file through the guard, in order, and records finished lines in `<queue-file>.done` so a re-run continues from the first unfinished stage. |

## How to use it as the agent

1. **Split the work into stages** that each finish in well under a 5-hour
   window and leave a result on disk. Write them one per line in a queue file;
   blank lines and `#` comments are ignored. Prefer stages whose outputs the
   user will want to read between runs.
2. **Launch detached**, so the queue survives the turn and the session:
   `nohup <skill>/scripts/run-queue.sh work.queue > work.launch.log 2>&1 &`.
   Note the paths in your reply; the user may want to watch them.
3. **Watch for completion with one notification**, not by polling: a background
   `until` loop or a Monitor that exits when the queue's log says `QUEUE DONE`,
   `STOP` appears in the state dir, or the runner process is gone. A Monitor
   lives at most an hour; re-arm it when it times out.
4. **Between stages, do the thinking**: read the stage's output, decide whether
   the next stage still makes sense, edit the queue file if it does not (unfinished
   lines can be changed; the runner re-reads the file before each stage).
5. **Report usage in every status message**: the numbers the guard logged before
   and after the stage, and what the guard is doing now (running, paused until
   the 5-hour reset time, or stopped). Say the reset time in the user's local time;
   the endpoint gives it in UTC.
6. **When the guard stops**, do not restart the queue by hand. Tell the user which
   window hit its threshold and when it resets. The user lifts the stop by
   deleting the STOP marker or raising the threshold.

## Gotchas

- The pause only protects the 5-hour window. If one stage is bigger than the
  headroom, it will overshoot; make stages smaller rather than thresholds lower.
- A stopped queue leaves `<queue-file>.done` in place. Delete it to start over.
- When usage cannot be read (no token, no network, endpoint 429) the guard uses
  the last reading for up to two hours, then waits and retries; it never runs a
  stage blind. A queue that seems stuck shows `usage unknown` in the guard log;
  fix the token (`claude` login) and it continues on its own.
- The numbers lag `/usage` by up to a minute.
