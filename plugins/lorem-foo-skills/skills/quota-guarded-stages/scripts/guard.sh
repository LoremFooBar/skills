#!/usr/bin/env bash
# guard.sh <command...>: run the command once the usage windows allow it.
# Exit 3 = stopped by a weekly limit (STOP marker written); else the command's exit code.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
STATE=${QUOTA_STATE_DIR:-$HOME/.claude/quota-guard}; mkdir -p "$STATE"
LOG="$STATE/guard.log"; RESUME=${QUOTA_RESUME_5H:-5}; INTERVAL=${QUOTA_CHECK_INTERVAL:-1800}
[ $# -gt 0 ] || { echo "usage: guard.sh <command...>" >&2; exit 64; }
if [ -f "$STATE/STOP" ]; then echo "$(date '+%F %T') refusing to run: $STATE/STOP exists ($(cat "$STATE/STOP"))" | tee -a "$LOG" >&2; exit 3; fi
while true; do
  u=$("$HERE/usage-check.sh"); rc=$?
  echo "$(date '+%F %T') $u rc=$rc next: $*" >> "$LOG"
  case $rc in
    0) break ;;
    2) h5=${u#5h=}; h5=${h5%% *}
       if [[ "$h5" =~ ^[0-9]+$ ]] && [ "$h5" -le "$RESUME" ]; then break; fi
       echo "$(date '+%F %T') paused: 5h window at ${h5}%, re-check in ${INTERVAL}s" >> "$LOG"; sleep "$INTERVAL" ;;
    3) echo "$(date '+%F %T') STOP: weekly limit reached ($u)" | tee -a "$LOG" > "$STATE/STOP"; exit 3 ;;
    4) echo "$(date '+%F %T') usage unknown ($u); waiting ${INTERVAL}s rather than running blind" >> "$LOG"; sleep "$INTERVAL" ;;
    *) echo "$(date '+%F %T') usage-check exited $rc unexpectedly; waiting ${INTERVAL}s" >> "$LOG"; sleep "$INTERVAL" ;;
  esac
done
"$@"; code=$?
u=$("$HERE/usage-check.sh" 2>/dev/null); echo "$(date '+%F %T') $u after: $* (exit $code)" >> "$LOG"
exit $code
