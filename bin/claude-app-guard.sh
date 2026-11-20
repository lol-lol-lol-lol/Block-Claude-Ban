#!/bin/bash
# Сторож: не даёт Claude Desktop работать мимо Сингапура.
# Если приложение запущено без нашего прокси — закрывает и поднимает заново
# через ярлык (с прокси). Так же лечится авто-перезапуск после обновления.
set -uo pipefail

DIR="$HOME/vpn/claude-net"
MYPROXY="socks5://127.0.0.1:2080"
LOG="$DIR/claude-guard.log"
LOCK="$DIR/.guard-relaunch"
COOLDOWN=20

pid=$(pgrep -x Claude | head -1)
[ -n "$pid" ] || exit 0

args=$(ps -p "$pid" -o args= 2>/dev/null)
case "$args" in
  *"--proxy-server=$MYPROXY"*) exit 0 ;;
esac

# защита от циклов: не чаще одного перезапуска в COOLDOWN секунд
if [ -f "$LOCK" ]; then
  last=$(cat "$LOCK" 2>/dev/null || echo 0)
  now=$(date +%s)
  [ $((now - last)) -lt "$COOLDOWN" ] && exit 0
fi
date +%s >"$LOCK"

echo "$(date '+%Y-%m-%d %H:%M:%S') Claude pid=$pid запущен без прокси — перезапускаю через Сингапур" >>"$LOG"

# закрыть неправильный
kill "$pid" 2>/dev/null
for _ in $(seq 1 20); do
  pgrep -x Claude >/dev/null || break
  sleep 0.25
done
pgrep -x Claude >/dev/null && kill -9 "$pid" 2>/dev/null
sleep 1

# поднять правильно
# запускаем через LaunchServices — так приложение получает нормальную GUI-сессию
open -a "$HOME/Applications/Claude SG.app"
exit 0
