#!/bin/bash
# One-time setup: keeps Anas HQ running at login and connects it to Claude.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
NODE="$(command -v node)"
PLIST="$HOME/Library/LaunchAgents/com.anashq.server.plist"
mkdir -p "$DIR/data"

# 1. Always-on server (starts at login, restarts if it crashes)
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.anashq.server</string>
  <key>ProgramArguments</key><array><string>$NODE</string><string>$DIR/server.js</string></array>
  <key>WorkingDirectory</key><string>$DIR</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$DIR/data/server.log</string>
  <key>StandardErrorPath</key><string>$DIR/data/server.log</string>
</dict>
</plist>
EOF
launchctl bootout "gui/$(id -u)/com.anashq.server" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "✓ Server running at http://localhost:4777 (starts automatically at login)"

# 2. Claude Code
if command -v claude >/dev/null; then
  claude mcp remove --scope user anas-hq >/dev/null 2>&1 || true
  claude mcp add --scope user anas-hq -- "$NODE" "$DIR/mcp.js"
  echo "✓ Connected to Claude Code"
fi

# 3. Claude desktop app (backs up its config first)
CFG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
if [ -f "$CFG" ]; then
  cp "$CFG" "$DIR/data/claude_desktop_config.backup.json"
  python3 -I - "$CFG" "$NODE" "$DIR/mcp.js" <<'PY'
import json, sys
p, node, mcp = sys.argv[1:4]
c = json.load(open(p))
c.setdefault('mcpServers', {})['anas-hq'] = {'command': node, 'args': [mcp]}
json.dump(c, open(p, 'w'), indent=2)
PY
  echo "✓ Connected to the Claude desktop app (quit and reopen it once)"
fi

# 4. Mac app (Dock, Spotlight, and a menu bar icon with your due-task count)
[ -d "$HOME/Applications/Anas HQ.app" ] || bash "$DIR/mac/build.sh"
open "$HOME/Applications/Anas HQ.app"
echo "✓ Opened Anas HQ. Right-click its Dock icon → Options → Keep in Dock to pin it"
