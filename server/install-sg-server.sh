#!/usr/bin/env bash
# Установка входного узла (VLESS + REALITY) на ваш сервер в Сингапуре.
# Запускать НА СЕРВЕРЕ под root:  bash install-sg-server.sh
# Проверено на Debian 12 / Ubuntu 22.04+. Порт 443 должен быть свободен.
set -euo pipefail

PORT="${PORT:-443}"
SNI="${SNI:-www.microsoft.com}"          # маскировка под чужой TLS-сайт
SB="$(command -v sing-box || echo /usr/local/bin/sing-box)"

[ "$(id -u)" = "0" ] || { echo "нужен root"; exit 1; }

echo "== 1/5 установка sing-box =="
if [ ! -x "$SB" ]; then
  curl -fsSL https://sing-box.app/install.sh | sh
fi
"$SB" version | head -1

echo "== 2/5 генерация ключей =="
KEYS="$("$SB" generate reality-keypair)"
PRIV="$(echo "$KEYS" | awk '/PrivateKey/{print $2}')"
PUB="$(echo "$KEYS" | awk '/PublicKey/{print $2}')"
UUID="$("$SB" generate uuid)"
SID="$("$SB" generate rand --hex 8)"
SERVER_IP="$(curl -fsS -m 10 https://api.ipify.org || echo 'IP_СЕРВЕРА')"

echo "== 3/5 конфиг =="
mkdir -p /etc/sing-box
cat >/etc/sing-box/config.json <<EOF
{
  "log": { "level": "warn", "timestamp": true },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": ${PORT},
      "users": [
        { "uuid": "${UUID}", "flow": "xtls-rprx-vision" }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${SNI}",
        "reality": {
          "enabled": true,
          "handshake": { "server": "${SNI}", "server_port": 443 },
          "private_key": "${PRIV}",
          "short_id": ["${SID}"]
        }
      }
    }
  ],
  "outbounds": [{ "type": "direct" }]
}
EOF
"$SB" check -c /etc/sing-box/config.json

echo "== 4/5 systemd =="
cat >/etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=sing-box server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=__SB__ run -c /etc/sing-box/config.json
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
sed -i "s|__SB__|$SB|" /etc/systemd/system/sing-box.service
systemctl daemon-reload
systemctl enable --now sing-box
sleep 2
systemctl --no-pager --lines=5 status sing-box || true

echo "== 5/5 firewall =="
if command -v ufw >/dev/null && ufw status | grep -q active; then ufw allow "${PORT}/tcp"; fi
if command -v firewall-cmd >/dev/null && firewall-cmd --state >/dev/null 2>&1; then
  firewall-cmd --permanent --add-port="${PORT}/tcp"; firewall-cmd --reload
fi

cat <<EOF

==================================================================
 ГОТОВО. Вставьте этот outbound в config.json на Mac в массив
 "outbounds" (первым) и добавьте "sg-vps" в список claude-chain.
==================================================================
    {
      "type": "vless",
      "tag": "sg-vps",
      "server": "${SERVER_IP}",
      "server_port": ${PORT},
      "uuid": "${UUID}",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "${SNI}",
        "utls": { "enabled": true, "fingerprint": "chrome" },
        "reality": {
          "enabled": true,
          "public_key": "${PUB}",
          "short_id": "${SID}"
        }
      }
    }
==================================================================
 Сервер: ${SERVER_IP}:${PORT}   SNI: ${SNI}
 Сохраните public_key и short_id — без них доступ не восстановить.
==================================================================
EOF
