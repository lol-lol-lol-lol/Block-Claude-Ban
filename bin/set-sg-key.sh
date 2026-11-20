#!/bin/bash
# Подставляет ключ Shadowsocks в config.json и делает его основным в цепочке Claude.
# Использование: ./bin/set-sg-key.sh 'ss://YWVz...@sin-sg-01.blncvpn4u.cc:9443#BlancVPN'
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CFG="${CFG:-$DIR/config.json}"
LINK="${1:-}"
[ -n "$LINK" ] || { echo "нужна ссылка ss://..."; exit 1; }

python3 - "$LINK" "$CFG" <<'PY'
import base64, json, sys
from urllib.parse import unquote

link, cfg_path = sys.argv[1], sys.argv[2]
if not link.startswith("ss://"):
    sys.exit("ссылка должна начинаться с ss://")

body = link[len("ss://"):]
body = body.split("#", 1)[0]
body, _, _query = body.partition("?")

def b64(s):
    s = s.replace("-", "+").replace("_", "/").strip()
    s += "=" * (-len(s) % 4)
    return base64.b64decode(s).decode()

if "@" in body:
    userinfo, hostport = body.rsplit("@", 1)
    method_pass = b64(userinfo) if ":" not in userinfo else unquote(userinfo)
else:
    decoded = b64(body)
    method_pass, hostport = decoded.rsplit("@", 1)

method, _, password = method_pass.partition(":")
host, _, port = hostport.rpartition(":")
if not method or not password or not host or not port.isdigit():
    sys.exit(f"не разобрал ссылку: method={method!r} host={host!r} port={port!r}")

cfg = json.load(open(cfg_path))

out = {
    "type": "shadowsocks",
    "tag": "sg-ss",
    "server": host,
    "server_port": int(port),
    "method": method,
    "password": password,
}

ob = [o for o in cfg["outbounds"] if o.get("tag") != "sg-ss"]
idx = next((i for i, o in enumerate(ob) if o.get("tag") == "claude-chain"), len(ob))
ob.insert(idx, out)
cfg["outbounds"] = ob

for o in cfg["outbounds"]:
    if o.get("tag") == "claude-chain":
        o["outbounds"] = ["sg-ss", "proxyline"]
        o["default"] = "sg-ss"

json.dump(cfg, open(cfg_path, "w"), indent=2, ensure_ascii=False)
open(cfg_path, "a").write("\n")
print(f"sg-ss = {host}:{port}  {method}  (пароль {len(password)} символов)")
PY

"$DIR/bin/sing-box" check -c "$CFG" && echo "конфиг валиден"
"$DIR/bin/claude-net" restart
sleep 1
"$DIR/bin/claude-net" check
