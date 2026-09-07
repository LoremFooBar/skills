#!/usr/bin/env bash
# Prints one status line fragment of usage percentages, coloured by threshold,
# with the time left on the 5-hour window beside it:
#   5h:100% (1h12m) | 7d:34% | fable:45% | credits:20%
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

# jq does the clock arithmetic so no extra process joins every prompt render.
rows=""
[ -r "$cache" ] && rows=$(jq -r '
  def epoch:
    capture("^(?<b>\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2})(\\.\\d+)?(?<z>Z|(?<sg>[+-])(?<zh>\\d{2}):(?<zm>\\d{2}))$")
    | (.b + "Z" | fromdateiso8601)
      - (if .z == "Z" then 0
         else ((.zh | tonumber) * 3600 + (.zm | tonumber) * 60)
              * (if .sg == "+" then 1 else -1 end)
         end);
  def left: [strings | epoch] | if length == 0 then "" else (.[0] - now | floor | tostring) end;
  def row($label): if . == null then empty else "\($label)\t\(.)\t" end;
  (.five_hour  | if . == null then empty else "5h\t\(.utilization)\t\(.resets_at | left)" end),
  (.seven_day.utilization  | row("7d")),
  (.limits[]? | select(.kind == "weekly_scoped" and .scope.model.display_name != null)
              | "\(.scope.model.display_name | ascii_downcase)\t\(.percent)\t"),
  (.extra_usage.utilization | row("credits"))' "$cache" 2>/dev/null)

# Claude Code's own snapshot is live, so it covers the windows it carries until
# the first fetch lands. It carries no reset time, so the countdown starts with
# the first successful fetch.
[ -z "$rows" ] && [ -n "$input" ] && rows=$(printf '%s' "$input" | jq -r '
  def row($label): if . == null then empty else "\($label)\t\(.)\t" end;
  (.rate_limits.five_hour.used_percentage   | row("5h")),
  (.rate_limits.seven_day.used_percentage   | row("7d")),
  (.rate_limits.spend_limit.used_percentage | row("credits"))' 2>/dev/null)

# A window past its reset means the cache is stale and a refresh is already in
# flight, so the countdown is dropped rather than shown as zero.
countdown() {
  local s=${1:-} h m
  [ -n "$s" ] && [ "$s" -gt 0 ] 2>/dev/null || return
  h=$(( s / 3600 )); m=$(( (s % 3600) / 60 ))
  if   [ "$h" -gt 0 ];  then printf '%dh%02dm' "$h" "$m"
  elif [ "$m" -gt 0 ];  then printf '%dm' "$m"
  else                       printf '<1m'
  fi
}

out=""; pre=""
while IFS=$'\t' read -r label pct secs; do
  [ -n "$label" ] && [ -n "$pct" ] || continue
  whole=${pct%%.*}; whole=${whole:-0}
  if   [ "$whole" -ge "$crit" ]; then colour=$'\033[38;5;131m'
  elif [ "$whole" -ge "$warn" ]; then colour=$'\033[38;5;178m'
  else                                colour=$'\033[38;5;65m'
  fi
  out+=$(printf '%s%s%s:%.0f%%\033[0m' "$pre" "$colour" "$label" "$pct")
  left=$(countdown "$secs")
  [ -n "$left" ] && out+=$(printf ' \033[38;5;240m(%s)\033[0m' "$left")
  pre="$sep"
done <<<"$rows"

printf '%s' "$out"
