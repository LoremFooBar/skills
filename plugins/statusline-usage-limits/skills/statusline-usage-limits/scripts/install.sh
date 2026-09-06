#!/usr/bin/env bash
# Wires usage-segments.sh into the user's status line. Creates a status line when
# none is configured; prints the snippet instead of editing an existing script,
# because a hand-written status line has no safe insertion point to guess at.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
settings="$HOME/.claude/settings.json"
segments="$here/usage-segments.sh"

for tool in jq curl python3; do
  command -v "$tool" >/dev/null || { echo "missing required tool: $tool" >&2; exit 1; }
done

current=""
[ -f "$settings" ] && current=$(jq -r '.statusLine.command // ""' "$settings" 2>/dev/null)

if [ -n "$current" ]; then
  cat <<SNIPPET
A status line is already configured:
  $current

Add these two lines to it, then print \$usage on its own line:

  usage=\$("$segments" "\$input")
  [ -n "\$usage" ] && printf '\\n%s' "\$usage"

The script expects the raw status line JSON as its argument. If your script names
that variable something other than \$input, pass that instead.
SNIPPET
  exit 0
fi

target="$HOME/.claude/statusline-command.sh"
cat > "$target" <<'LINE'
#!/usr/bin/env bash
input=$(cat)

model=$(printf '%s' "$input" | jq -r '.model.display_name // "claude"')
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // ""')
ctx=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')

out="$model | ${cwd/#$HOME/~}"
[ -n "$ctx" ] && out+=$(printf ' | ctx:%.0f%%' "$ctx")

usage=$(__SEGMENTS__ "$input")
[ -n "$usage" ] && out+=$'\n'"$usage"

printf '%s' "$out"
LINE
sed -i.bak "s|__SEGMENTS__|\"$segments\"|" "$target" && rm -f "$target.bak"
chmod +x "$target"

mkdir -p "$HOME/.claude"
[ -f "$settings" ] || echo '{}' > "$settings"
tmp=$(mktemp)
jq --arg cmd "$target" '.statusLine = {type: "command", command: $cmd}' "$settings" > "$tmp"
mv "$tmp" "$settings"

echo "Created $target and registered it in $settings"
echo "Preview:"
printf '{"model":{"display_name":"Claude"},"workspace":{"current_dir":"%s"}}' "$HOME" | bash "$target"
echo
