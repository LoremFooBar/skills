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
  # Linux and WSL keep the credentials in a file; macOS keeps them in the Keychain.
  if [ -r "$HOME/.claude/.credentials.json" ]; then
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["claudeAiOauth"]["accessToken"])' \
      "$HOME/.claude/.credentials.json" 2>/dev/null && return 0
  fi
  security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null |
    python3 -c 'import sys,json; print(json.load(sys.stdin)["claudeAiOauth"]["accessToken"])' 2>/dev/null
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
