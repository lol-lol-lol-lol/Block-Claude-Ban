# Troubleshooting

Start with two commands — they answer 90% of the questions:

```bash
claude-net status
claude-net trace
```

## The gateway will not start

```bash
claude-net start
launchctl print gui/$(id -u)/com.claude-net.gateway | head -20
tail -20 ~/vpn/claude-net/sing-box.log
```

Common causes:

- **`exit 78 (EX_CONFIG)`** — the process cannot read the config. This happens when the
  project lives in `~/Documents`, `~/Desktop` or `~/Downloads`: macOS protects those
  directories (TCC) and a background process gets no access. Keep the project in `~/vpn`
  or `~/Library/Application Support`.
- **port already in use** — `lsof -iTCP:2080`. Two gateway instances conflict.
- **broken config** — `sing-box check -c config.json`.

## Claude Desktop uses the wrong path

```bash
claude-desktop --check     # does the gateway resolve to Singapore
claude-desktop --restart
```

Check where connections actually go:

```bash
lsof -nP -iTCP | grep -i claude | awk '{print $9}'
```

- `127.0.0.1:2080` — correct, through the gateway;
- `127.0.0.1:1082` (or your VPN client port) — the app picked up the system proxy and
  went around.

## Direct access to Anthropic is not blocked

```bash
curl -sS -m 5 -o /dev/null -w '%{http_code}\n' https://api.anthropic.com/
```

It must be `000`. If it returns `401`, the firewall is misconfigured and traffic can
leak.

## REALITY does not connect

Symptom: `reality verification failed`.

1. Make sure the server `private_key` and the client `public_key` are the same pair.
2. Check that `short_id` and `server_name` match.
3. If the connection goes through another VPN tunnel, try a different protocol
   (Shadowsocks-2022): some networks break the REALITY handshake.

## Subscription returns 404

Panels use different paths. Check `subPath` in the panel settings — the configured path
and the path in the link must match character by character.

## Claude Code has no network inside the sandbox

That is intended: `sandbox/claude-code.sb` allows localhost connections only. If you need
more, extend the profile deliberately.
