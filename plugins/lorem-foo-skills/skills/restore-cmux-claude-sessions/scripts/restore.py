#!/usr/bin/env python3
"""Resume the Claude session of each cmux tab from cmux's saved session snapshots."""
import argparse
import glob
import json
import os
import shlex
import subprocess
import sys
import time

SUPPORT = os.path.expanduser("~/Library/Application Support/cmux")
SHELLS = {"zsh", "-zsh", "bash", "-bash", "fish", "-fish", "sh", "-sh", "login"}


def snapshots():
    files = glob.glob(os.path.join(SUPPORT, "session-history", "*.json"))
    files += glob.glob(os.path.join(SUPPORT, "session-com.cmuxterm.app*.json"))
    out = []
    for f in files:
        try:
            with open(f) as fh:
                d = json.load(fh)
        except (OSError, ValueError):
            continue
        out.append((d.get("createdAt") or os.path.getmtime(f), f, d))
    out.sort(key=lambda x: x[0])
    return out


def cmux_started():
    r = subprocess.run(["ps", "-axo", "pid=,lstart=,comm="], capture_output=True, text=True)
    for line in r.stdout.splitlines():
        if line.rstrip().endswith("cmux.app/Contents/MacOS/cmux"):
            parts = line.split()
            return time.mktime(time.strptime(" ".join(parts[1:6]), "%a %b %d %H:%M:%S %Y"))
    sys.exit("cmux is not running")


def claude_binding(ws, p, created):
    t = p.get("terminal") or {}
    rb = t.get("resumeBinding") or {}
    ag = t.get("agent") or {}
    sid = rb.get("checkpointId") or ag.get("sessionId")
    if not sid or (rb.get("kind") or ag.get("kind")) != "claude":
        return None
    args = (rb.get("launchCommand") or ag.get("launchCommand") or {}).get("arguments") or []
    return {
        "session": sid,
        "cwd": rb.get("cwd") or ag.get("workingDirectory") or p.get("directory") or os.path.expanduser("~"),
        "args": args[1:],
        "snapshot": created,
        "workspace": ws.get("customTitle") or ws.get("processTitle") or "",
        "title": p.get("title") or "",
    }


def bindings():
    """Claude binding per panel id. The newest snapshot that holds the panel wins,
    with one exception: cmux writes tabs it restored but did not resume as plain
    shells, so when the newest snapshot is from after the current cmux launch and
    has no binding, the last snapshot from before the launch decides. cmux drops
    the binding when Claude exits normally, so a session that was exited before
    the crash stays closed."""
    started = cmux_started()
    before, after = {}, {}
    for created, f, d in snapshots():
        side = after if created >= started else before
        for w in d.get("windows", []):
            for ws in w.get("tabManager", {}).get("workspaces", []):
                for p in ws.get("panels", []):
                    side[p["id"].upper()] = claude_binding(ws, p, created)
    found = {}
    for pid in set(before) | set(after):
        b = after.get(pid) or before.get(pid)
        if b:
            found[pid] = b
    return found


def resume_flags(args):
    """Keep the original launch flags, minus the ones that pick a session or pass a prompt."""
    drop_with_value = {"--resume", "-r", "--session-id", "--settings", "--mcp-config"}
    drop = {"--continue", "-c"}
    with_value = {"--permission-mode", "--model", "--add-dir", "--agent", "--effort",
                  "--append-system-prompt", "--fallback-model"}
    out, i = [], 0
    while i < len(args):
        a = args[i]
        name = a.split("=", 1)[0]
        if name in drop_with_value:
            i += 1 if "=" in a else 2
            continue
        if name in drop or not a.startswith("-"):
            i += 1
            continue
        out.append(a)
        if name in with_value and "=" not in a and i + 1 < len(args):
            out.append(args[i + 1])
            i += 1
        i += 1
    return out


def running_sessions():
    ids = set()
    for f in glob.glob(os.path.expanduser("~/.claude/sessions/*.json")):
        try:
            with open(f) as fh:
                d = json.load(fh)
            os.kill(int(d["pid"]), 0)
            ids.add(d["sessionId"])
        except (OSError, ValueError, KeyError, TypeError):
            continue
    return ids


def tty_busy(tty):
    """True when something other than the login shell runs on the tab's terminal.
    Typing into a busy tab would feed the command to that program instead. A tab
    whose shell has not started yet has no tty; cmux queues the input until it does."""
    if not tty:
        return False
    r = subprocess.run(["ps", "-t", tty, "-o", "comm="], capture_output=True, text=True)
    procs = [os.path.basename(x.strip()) for x in r.stdout.splitlines() if x.strip()]
    return any(p not in SHELLS for p in procs)


def surfaces():
    r = subprocess.run(["cmux", "--json", "tree", "--id-format", "both"], capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"cmux tree failed: {r.stderr.strip()}")
    t = json.loads(r.stdout)
    for w in t["windows"]:
        for ws in w["workspaces"]:
            for p in ws["panes"]:
                for s in p["surfaces"]:
                    if s.get("type") == "terminal":
                        yield ws, s


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="send the resume commands (default: only print the plan)")
    ap.add_argument("--delay", type=float, default=3.0, help="seconds between tabs")
    a = ap.parse_args()

    found = bindings()
    running = running_sessions()
    plan, skipped, used = [], [], set()
    for ws, s in surfaces():
        b = found.get(s["id"].upper())
        label = f'{ws.get("title") or ""} / {s.get("title") or ""}'.strip()
        if not b:
            continue
        if b["session"] in running:
            skipped.append((s["ref"], label, "already running"))
        elif b["session"] in used:
            skipped.append((s["ref"], label, "same session planned in another tab"))
        elif tty_busy(s.get("tty")):
            skipped.append((s["ref"], label, "tab is busy"))
        elif not os.path.isdir(b["cwd"]):
            skipped.append((s["ref"], label, f'folder is gone: {b["cwd"]}'))
        else:
            used.add(b["session"])
            cmd = " ".join(["cd", "--", shlex.quote(b["cwd"]), "&&", "claude", "--resume", b["session"]]
                           + [shlex.quote(x) for x in resume_flags(b["args"])])
            plan.append((s["ref"], label, b, cmd))

    open_ids = {s["id"].upper() for _, s in surfaces()}
    lost = [b for pid, b in found.items() if pid not in open_ids and b["session"] not in running]
    lost = [b for b in lost if time.time() - b["snapshot"] < 3 * 86400]

    print(f"RESUME {len(plan)}")
    for ref, label, b, cmd in plan:
        age = (time.time() - b["snapshot"]) / 3600
        print(f"  {ref}\t{label}\t{b['session']}\tsnapshot {age:.1f}h old")
    print(f"SKIP {len(skipped)}")
    for ref, label, why in skipped:
        print(f"  {ref}\t{label}\t{why}")
    print(f"NO-TAB {len(lost)} (sessions from the last 3 days whose tab no longer exists)")
    for b in sorted(lost, key=lambda b: -b["snapshot"]):
        print(f"  {b['session']}\t{b['workspace']} / {b['title']}\t{b['cwd']}")

    if not a.apply:
        return
    fails = 0
    for i, (ref, label, b, cmd) in enumerate(plan):
        ok = subprocess.run(["cmux", "send", "--surface", ref, cmd], capture_output=True).returncode == 0
        ok = ok and subprocess.run(["cmux", "send-key", "--surface", ref, "enter"], capture_output=True).returncode == 0
        print(f"{'OK  ' if ok else 'FAIL'} {ref}\t{label}", flush=True)
        fails += not ok
        if i + 1 < len(plan):
            time.sleep(a.delay)
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
