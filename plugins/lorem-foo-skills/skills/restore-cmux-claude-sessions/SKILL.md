---
name: restore-cmux-claude-sessions
description: Resume the Claude session of every cmux tab after cmux restarts without resuming them - after a crash, a forced quit, a reboot, or a Cmd+Q where auto-resume did not work. Reads cmux's saved session snapshots, finds the Claude session each open tab had, and types the resume command into each idle tab. Use when the user says "my sessions did not restore", "cmux crashed", "restore my claude sessions", "resume all tabs", or asks to restore Claude sessions in cmux. macOS only.
disable-model-invocation: true
---

# Restore Claude sessions in cmux tabs

cmux saves each tab's Claude session (`resumeBinding`) in
`~/Library/Application Support/cmux/session-com.cmuxterm.app*.json` and
`session-history/`. After an unclean exit, cmux restores the tabs as plain
shells and does not resume them. `scripts/restore.py` in this skill's directory
reads the last state saved before the current cmux launch and sends
`cd -- <cwd> && claude --resume <id> <flags>` to each tab.

The commands below call it through the marketplace clone, whose path stays the
same across plugin versions. Without the plugin, use the path of your copy.

## Steps

1. Dry run. It changes nothing:
   ```sh
   python3 -I ~/.claude/plugins/marketplaces/loremfoobar-skills/plugins/lorem-foo-skills/skills/restore-cmux-claude-sessions/scripts/restore.py
   ```
   Output sections:
   - `RESUME`: tabs that will get their session back, with the session id and the age of the snapshot it came from.
   - `SKIP`: tabs left alone. `already running` = the session is live somewhere. `tab is busy` = another program runs in the tab. `folder is gone` = the working directory was deleted.
   - `NO-TAB`: sessions from the last 3 days whose tab no longer exists. These are not resumed.
2. Show the user the counts and the `RESUME` list as a short table (workspace / tab title, session id). Point out any snapshot older than about 1 day, because it may be a stale state. Ask once whether to go ahead. If they want to leave some tabs out, resume the rest by hand with the commands below rather than the script.
3. Apply:
   ```sh
   python3 -I ~/.claude/plugins/marketplaces/loremfoobar-skills/plugins/lorem-foo-skills/skills/restore-cmux-claude-sessions/scripts/restore.py --apply
   ```
   Run it with `run_in_background`, because it waits 3 seconds between tabs (60 tabs take about 3 minutes). Starting all sessions at once puts a large load on the machine right after boot. It prints `OK` or `FAIL` per tab and exits with 1 if any tab failed.
4. Check: run the dry run again. Every tab from step 2 should now show `already running`. Report the tabs that failed, and the `NO-TAB` sessions with their resume commands, so the user can open them where they want.

## Resume one tab by hand

```sh
cmux send --surface <surface-ref> "cd -- '<cwd>' && claude --resume <session-id>"
cmux send-key --surface <surface-ref> enter
```

Get surface refs and titles with `cmux --json tree --id-format both`.

## Notes

- Requires macOS, cmux, Python 3, and Claude Code.
- This session's own tab shows `already running`, so the skill can run from any tab.
- A plain `claude` in a cmux shell goes through cmux's per-tab shim, so cmux hooks and notifications keep working in resumed sessions.
- The original launch flags are kept (`--permission-mode`, `--model`, and others). Flags that cmux adds itself (`--settings`, `--mcp-config`), a session flag, and a prompt argument are dropped.
- A tab whose shell has not started yet (no tty) still gets the command: cmux queues the input until the shell is ready.
- Why auto-resume fails: after an unclean exit, cmux shows a "Restore agent sessions?" dialog instead, and its "Restore" opens each session in a new workspace, not in the original tab. On cmux 0.65.2 auto-resume can also fail after a clean Cmd+Q when `automation.socketControlMode` is `password` (manaflow-ai/cmux#21177).
