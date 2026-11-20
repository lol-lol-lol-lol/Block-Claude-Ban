#!/bin/bash
# Проверка «отказал туннель — трафик не утёк».
# Останавливает шлюз, пробует достучаться до Anthropic напрямую и через шлюз.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'

echo "1) шлюз работает?"
"$DIR/bin/claude-net" status

echo
echo "2) останавливаем шлюз (имитация падения туннеля)"
"$DIR/bin/claude-net" stop >/dev/null

echo
echo "3) клиент с настройкой прокси — должен получить ОШИБКУ, а не пойти напрямую:"
curl -sS -m 8 --proxy socks5h://127.0.0.1:2080 -A "$UA" -o /dev/null -w '   код=%{http_code}\n' https://claude.ai/ 2>&1 | sed 's/^/   /'

echo
echo "4) прямой запрос к Anthropic (так поступит приложение, игнорирующее прокси):"
code=$(curl -sS -m 10 -A "$UA" -o /dev/null -w '%{http_code}' https://api.anthropic.com/v1/models 2>/dev/null || echo FAIL)
echo "   без Little Snitch код=$code  ← это и есть утечка, которую перекрывает deny-правило"

echo
echo "5) поднимаем шлюз обратно"
"$DIR/bin/claude-net" start >/dev/null && echo "   ok"
