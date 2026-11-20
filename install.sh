#!/bin/bash
# Установка Claude Net: шлюз, автозапуск, сторож Claude Desktop, ярлык.
#   ./install.sh              установить в ~/vpn/claude-net
#   DIR=/opt/claude-net ./install.sh   в другую папку
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="${DIR:-$HOME/vpn/claude-net}"
LA="$HOME/Library/LaunchAgents"
BIN="$HOME/bin"

say() { printf '\033[1m%s\033[0m\n' "$*"; }

say "1/6 папка $DIR"
mkdir -p "$DIR/bin" "$DIR/sandbox" "$DIR/launchd" "$LA" "$BIN"
cp -f "$SRC"/bin/* "$DIR/bin/" 2>/dev/null || true
cp -f "$SRC"/sandbox/* "$DIR/sandbox/"
chmod +x "$DIR"/bin/*

say "2/6 sing-box"
if [ ! -x "$DIR/bin/sing-box" ]; then
  ARCH="$(uname -m)"; case "$ARCH" in arm64) A=arm64;; *) A=amd64;; esac
  VER="$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/SagerNet/sing-box/releases/latest | sed 's#.*/tag/##')"
  [ -n "$VER" ] || { echo "не удалось узнать версию sing-box"; exit 1; }
  TMP="$(mktemp -d)"
  curl -fsSL "https://github.com/SagerNet/sing-box/releases/download/$VER/sing-box-${VER#v}-darwin-$A.tar.gz" -o "$TMP/sb.tgz"
  tar xzf "$TMP/sb.tgz" -C "$TMP"
  cp "$TMP"/sing-box-*/sing-box "$DIR/bin/sing-box"
  chmod +x "$DIR/bin/sing-box"; rm -rf "$TMP"
fi
"$DIR/bin/sing-box" version | head -1

say "3/6 конфиг"
if [ ! -f "$DIR/config.json" ]; then
  cp "$SRC/config.example.json" "$DIR/config.json"
  chmod 600 "$DIR/config.json"
  echo "  создан config.json из примера — заполните YOUR_* поля"
else
  echo "  config.json уже есть, не трогаю"
fi

say "4/6 ярлыки в ~/bin"
for c in claude-net claude-desktop claude-safe chrome-claude comet-claude; do
  [ -f "$DIR/bin/$c" ] && ln -sfn "$DIR/bin/$c" "$BIN/$c"
done

say "5/6 LaunchAgents"
render() { sed "s#__DIR__#$DIR#g" "$1" > "$2"; }
render "$SRC/launchd/gateway.plist.template" "$LA/com.claude-net.gateway.plist"
render "$SRC/launchd/appguard.plist.template" "$LA/com.claude-net.appguard.plist"
launchctl bootout "gui/$(id -u)/com.claude-net.gateway" 2>/dev/null || true
launchctl bootout "gui/$(id -u)/com.claude-net.appguard" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$LA/com.claude-net.gateway.plist"
launchctl bootstrap "gui/$(id -u)" "$LA/com.claude-net.appguard.plist"

say "6/6 ярлык Claude SG"
"$DIR/bin/claude-net" start >/dev/null 2>&1 || true
APPDIR="$HOME/Applications"; APP="$APPDIR/Claude SG.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Claude SG</string>
  <key>CFBundleIdentifier</key><string>local.claudenet.claudesg</string>
  <key>CFBundleExecutable</key><string>launch</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>Icon</string>
</dict></plist>
PLIST
printf '#!/bin/bash\nexec %q\n' "$DIR/bin/claude-desktop" > "$APP/Contents/MacOS/launch"
chmod +x "$APP/Contents/MacOS/launch"
[ -f /Applications/Claude.app/Contents/Resources/electron.icns ] && \
  cp /Applications/Claude.app/Contents/Resources/electron.icns "$APP/Contents/Resources/Icon.icns"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" 2>/dev/null || true

cat <<EOF

Готово. Дальше:
  1. заполните $DIR/config.json (сервер, пароль, резерв)
  2. $DIR/bin/claude-net check
  3. откройте «Claude SG» из ~/Applications
EOF
