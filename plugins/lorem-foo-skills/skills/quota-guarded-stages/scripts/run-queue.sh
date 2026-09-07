#!/usr/bin/env bash
# run-queue.sh <queue-file>: run each stage line through guard.sh, in order.
# Finished lines are appended to <queue-file>.done; a re-run skips them, so an
# interrupted or stopped queue continues from the first unfinished stage. The
# queue file is re-read before every stage, so unfinished lines may be edited
# while it runs. Set QUOTA_CONTINUE_ON_FAIL=1 to go on after a failing stage.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
Q=${1:?queue file}; DONE="$Q.done"; touch "$DONE"
STATE=${QUOTA_STATE_DIR:-$HOME/.claude/quota-guard}; mkdir -p "$STATE"
while true; do
  stage=""
  while IFS= read -r line || [ -n "$line" ]; do
    [[ -z "${line// }" || "$line" == \#* ]] && continue
    grep -qxF -- "$line" "$DONE" && continue
    stage=$line; break
  done < "$Q"
  [ -n "$stage" ] || { echo "$(date '+%F %T') QUEUE DONE: $Q"; exit 0; }
  echo "$(date '+%F %T') STAGE START: $stage"
  bash "$HERE/guard.sh" bash -c "$stage"; rc=$?
  if [ $rc -eq 3 ] && [ -f "$STATE/STOP" ]; then echo "$(date '+%F %T') QUEUE STOPPED by quota guard before: $stage"; exit 3; fi
  if [ $rc -ne 0 ] && [ "${QUOTA_CONTINUE_ON_FAIL:-0}" != "1" ]; then echo "$(date '+%F %T') QUEUE HALTED: stage exited $rc: $stage"; exit $rc; fi
  printf '%s\n' "$stage" >> "$DONE"
  echo "$(date '+%F %T') STAGE END (exit $rc): $stage"
done
