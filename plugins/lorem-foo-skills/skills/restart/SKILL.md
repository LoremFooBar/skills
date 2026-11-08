---
name: restart
description: Restart Claude Code sessions that run in cmux tabs so they use the newly installed version, and resume each one in the same tab with the same session and flags. Use when asked to "restart this session", "restart yourself", "apply the Claude Code update", "restart all claude sessions", or "reload claude in every cmux tab".
---

# Restart Claude Code in cmux

Script: `scripts/claude-restart` in this skill's directory. The commands below call it as `claude-restart`. If `command -v claude-restart` finds nothing, run it by its full path, or link it onto PATH once:

```bash
ln -sf ~/.claude/plugins/marketplaces/loremfoobar-skills/plugins/lorem-foo-skills/skills/restart/scripts/claude-restart ~/.local/bin/claude-restart
```

That path is the marketplace clone, which keeps the same path across plugin versions. The plugin cache path has the version in it and breaks on the next update.

Requirements: cmux, `jq`, `perl`, and Claude Code from the native installer (the installed version is read from the `~/.local/bin/claude` symlink).

## Restart this session

```bash
claude-restart --self
```

The command returns at once. A background process waits until this turn ends, stops this session with SIGTERM, and types the resume command into the same cmux tab. After you run it, give a one-line reply and end the turn. The session comes back within a few seconds.

## Restart all sessions

1. Preview first: `claude-restart --dry-run`
2. Show the user the list, then run `claude-restart`.

Default behavior:
- Restarts only sessions that run an older version than `~/.local/bin/claude`. `--all-versions` restarts all of them.
- Skips sessions in the middle of a turn. `--include-busy` stops them too, and the turn in progress is lost.
- The session that runs the command restarts last, after its turn ends, in the same way as `--self`.
- `--surface <uuid>` limits the run to one cmux tab.

## How it works

- `~/.claude/sessions/<pid>.json` gives each live session's id, status (`idle`/`busy`) and version.
- `CMUX_SURFACE_ID` in the process environment gives the cmux tab. `cmux tree` leaves `tty` empty for many tabs, so it cannot be used to match processes to tabs.
- `cmux surface resume show --surface <uuid> --json` gives the resume command cmux itself uses. That command keeps the original flags, such as `--permission-mode auto`.
- The script stops a session with SIGTERM. Typing `/exit` is unsafe: Ctrl+C does not clear a draft, so the draft plus `/exit` is sent as a message.
