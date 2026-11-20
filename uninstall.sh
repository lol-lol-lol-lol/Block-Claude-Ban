#!/bin/bash
# Удаление: агенты, симлинки, ярлык. Папку с конфигом не трогает.
set -uo pipefail
DIR="${DIR:-$HOME/vpn/claude-net}"

for j in com.claude-net.gateway com.claude-net.appguard local.claudenet.appguard; do
  launchctl bootout "gui/$(id -u)/$j" 2>/dev/null || true
  rm -f "$HOME/Library/LaunchAgents/$j.plist"
done

pkill -f "$DIR/bin/sing-box run" 2>/dev/null || true
rm -f "$HOME/bin"/{claude-net,claude-desktop,claude-safe,chrome-claude,comet-claude}
rm -rf "$HOME/Applications/Claude SG.app"

echo "Агенты и ярлыки удалены. Конфиг остался в $DIR"
