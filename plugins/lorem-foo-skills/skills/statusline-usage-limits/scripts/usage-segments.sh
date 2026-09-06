#!/usr/bin/env bash
# Prints one status line fragment of usage percentages, coloured by threshold:
#   5h:100% | 7d:34% | fable:45% | credits:20%
#
# Usage: usage-segments.sh "$input"   (input = the status line JSON on stdin of
# the caller). Prints nothing when no window is known, so callers can drop the
# separator with a plain emptiness test.
#
# Reads the cache usage-refresh.sh writes and never calls the network itself;
# fetching inline would put a round trip in front of every prompt render.
set -uo pipefail

input="${1:-}"
cache="${USAGE_LIMITS_CACHE:-$HOME/.claude/cache/usage.json}"
stamp="${cache%.json}.attempt"
warn="${USAGE_LIMITS_WARN:-70}"
crit="${USAGE_LIMITS_CRIT:-90}"
sep="${USAGE_LIMITS_SEP:- | }"
refresh="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/usage-refresh.sh"

mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0; }

now=$(date +%s)
if [ $(( now - $(mtime "$cache") )) -gt "${USAGE_LIMITS_TTL:-120}" ] &&
   [ $(( now - $(mtime "$stamp") )) -gt 60 ] && [ -x "$refresh" ]; then
  # Rate-limit the spawn on its own stamp so a failing fetch cannot start a new
  # process on every render.
  mkdir -p "$(dirname "$stamp")" && touch "$stamp"
  ( nohup "$refresh" >/dev/null 2>&1 & ) &
  disown 2>/dev/null
fi

rows=""
[ -r "$cache" ] && rows=$(jq -r '
  def row($label): if . == null then empty else "\($label)\t\(.)" end;
  (.five_hour.utilization  | row("5h")),
  (.seven_day.utilization  | row("7d")),
  (.limits[]? | select(.kind == "weekly_scoped" and .scope.model.display_name != null)
              | "\(.scope.model.display_name | ascii_downcase)\t\(.percent)"),
  (.extra_usage.utilization | row("credits"))' "$cache" 2>/dev/null)

# Claude Code's own snapshot is live, so it covers the windows it carries until
# the first fetch lands.
[ -z "$rows" ] && [ -n "$input" ] && rows=$(printf '%s' "$input" | jq -r '
  def row($label): if . == null then empty else "\($label)\t\(.)" end;
  (.rate_limits.five_hour.used_percentage   | row("5h")),
  (.rate_limits.seven_day.used_percentage   | row("7d")),
  (.rate_limits.spend_limit.used_percentage | row("credits"))' 2>/dev/null)

out=""; pre=""
while IFS=$'\t' read -r label pct; do
  [ -n "$label" ] && [ -n "$pct" ] || continue
  whole=${pct%%.*}; whole=${whole:-0}
  if   [ "$whole" -ge "$crit" ]; then colour=$'\033[38;5;131m'
  elif [ "$whole" -ge "$warn" ]; then colour=$'\033[38;5;178m'
  else                                colour=$'\033[38;5;65m'
  fi
  out+=$(printf '%s%s%s:%.0f%%\033[0m' "$pre" "$colour" "$label" "$pct")
  pre="$sep"
done <<<"$rows"

printf '%s' "$out"
