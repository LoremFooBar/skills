#!/usr/bin/env bash
# Caches the claude.ai usage snapshot for the status line. The per-model weekly
# windows (Fable, Opus, Sonnet) and the usage-credit balance are absent from the
# status line JSON Claude Code supplies and exist only on this endpoint. Every
# failure exits 0 and leaves the previous cache in place, so the status line keeps
# rendering the last known numbers instead of losing the segments.
#
# Passing skip_spend=1 makes the endpoint return spend and extra_usage as null,
# which silently removes the credits segment.
set -uo pipefail

cache="${USAGE_LIMITS_CACHE:-$HOME/.claude/cache/usage.json}"
mkdir -p "$(dirname "$cache")"
tmp=$(mktemp "${cache}.XXXXXX") || exit 0
trap 'rm -f "$tmp"' EXIT

read_token() {
  # An expired token is answered with 429, not 401, so an unchecked stale
  # credential freezes the cache silently instead of failing loudly. macOS keeps
  # the live credential in the Keychain; a leftover .credentials.json can sit
  # months out of date beside it.
  python3 - "$HOME/.claude/.credentials.json" <<'CREDS'
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
        return subprocess.run(
            ["security", "find-generic-password", "-s", "Claude Code-credentials", "-w"],
            capture_output=True, text=True, timeout=5,
        ).stdout
    except Exception:
        return ""


def credentials_file():
    try:
        with open(sys.argv[1]) as fh:
            return fh.read()
    except Exception:
        return ""


for raw in (keychain(), credentials_file()):
    found = token(raw)
    if found:
        print(found)
        break
CREDS
}

token=$(read_token)
[ -n "$token" ] || exit 0

curl -fsS --max-time 10 \
  "https://api.anthropic.com/api/oauth/usage?at_wall=1" \
  -H "Authorization: Bearer $token" \
  -H "anthropic-beta: oauth-2025-04-20" \
  -o "$tmp" || exit 0

python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$tmp" 2>/dev/null || exit 0
mv "$tmp" "$cache"
trap - EXIT
