#!/usr/bin/env bash
# Prints "5h=NN 7d=NN <model>=NN ... 5h_resets_at=<utc>" and exits
#   0 go, 2 pause (5-hour window at or above QUOTA_PAUSE_5H),
#   3 stop (weekly window at or above QUOTA_STOP_7D, or a per-model window at or
#     above QUOTA_STOP_MODEL; both default to QUOTA_STOP_WEEKLY),
#   4 unknown (no fresh or recent usage data; the guard waits rather than runs).
# The endpoint answers bursts with 429, so a reading is cached for QUOTA_CACHE_TTL
# seconds and, when a fetch fails, reused for up to QUOTA_STALE_MAX seconds.
# QUOTA_USAGE_JSON=<file> bypasses the network (for tests).
set -uo pipefail
PAUSE=${QUOTA_PAUSE_5H:-90}; STOP=${QUOTA_STOP_WEEKLY:-85}; STOP7D=${QUOTA_STOP_7D:-$STOP}; STOPMODEL=${QUOTA_STOP_MODEL:-$STOP}; MODEL=${QUOTA_MODEL:-}
STATE=${QUOTA_STATE_DIR:-$HOME/.claude/quota-guard}; mkdir -p "$STATE"
CACHE="$STATE/usage.json"; TTL=${QUOTA_CACHE_TTL:-60}; STALE_MAX=${QUOTA_STALE_MAX:-7200}

age() { local now m; now=$(date +%s); m=$(stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0); echo $((now - m)); }

fetch() {
  local token
  token=$(python3 - "$HOME/.claude/.credentials.json" <<'PY'
import json, subprocess, sys, time
def token(raw):
    try:
        oauth = json.loads(raw)["claudeAiOauth"]
    except Exception:
        return None
    if oauth.get("expiresAt", 0) / 1000 <= time.time():
        return None
    return oauth.get("accessToken")
def keychain():
    try:
        return subprocess.run(["security", "find-generic-password", "-s", "Claude Code-credentials", "-w"],
                              capture_output=True, text=True, timeout=5).stdout
    except Exception:
        return ""
def credfile():
    try:
        return open(sys.argv[1]).read()
    except Exception:
        return ""
for raw in (keychain(), credfile()):
    t = token(raw)
    if t:
        print(t); break
PY
  )
  [ -n "$token" ] || { echo "usage-check: no OAuth token (Keychain or ~/.claude/.credentials.json)" >&2; return 1; }
  local tmp; tmp=$(mktemp "$CACHE.XXXXXX") || return 1
  if curl -fsS --max-time 10 "https://api.anthropic.com/api/oauth/usage?at_wall=1" \
       -H "Authorization: Bearer $token" -H "anthropic-beta: oauth-2025-04-20" -o "$tmp" \
     && jq -e . "$tmp" >/dev/null 2>&1; then mv "$tmp" "$CACHE"; return 0; fi
  rm -f "$tmp"; echo "usage-check: fetch failed" >&2; return 1
}

if [ -n "${QUOTA_USAGE_JSON:-}" ]; then
  src=$QUOTA_USAGE_JSON
else
  if [ ! -f "$CACHE" ] || [ "$(age "$CACHE")" -gt "$TTL" ]; then fetch || true; fi
  if [ ! -f "$CACHE" ]; then echo "5h=? 7d=? (no usage data)"; exit 4; fi
  if [ "$(age "$CACHE")" -gt "$STALE_MAX" ]; then echo "5h=? 7d=? (usage data $(age "$CACHE")s old)"; exit 4; fi
  [ "$(age "$CACHE")" -gt "$TTL" ] && echo "usage-check: using cached reading $(age "$CACHE")s old" >&2
  src=$CACHE
fi

jq -e . "$src" >/dev/null 2>&1 || { echo "5h=? 7d=? (unreadable usage data: $src)"; exit 4; }
h5=$(jq -r '.five_hour.utilization // 0 | floor' "$src")
d7=$(jq -r '.seven_day.utilization // 0 | floor' "$src")
reset=$(jq -r '.five_hour.resets_at // ""' "$src")
scoped=$(jq -r --arg m "$MODEL" '[.limits[]? | select(.kind=="weekly_scoped" and ($m=="" or .scope.model.display_name==$m)) | "\(.scope.model.display_name|ascii_downcase)=\(.percent)"] | join(" ")' "$src")
maxscoped=$(jq -r --arg m "$MODEL" '[.limits[]? | select(.kind=="weekly_scoped" and ($m=="" or .scope.model.display_name==$m)) | .percent] | max // 0' "$src")

[[ "$h5" =~ ^[0-9]+$ && "$d7" =~ ^[0-9]+$ && "$maxscoped" =~ ^[0-9]+$ ]] || { echo "5h=? 7d=? (unexpected usage shape)"; exit 4; }
echo "5h=$h5 7d=$d7 ${scoped:+$scoped }5h_resets_at=$reset"
if [ "$d7" -ge "$STOP7D" ] || [ "$maxscoped" -ge "$STOPMODEL" ]; then exit 3; fi
if [ "$h5" -ge "$PAUSE" ]; then exit 2; fi
exit 0
