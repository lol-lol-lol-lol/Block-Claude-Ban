# Security

## No secrets in this repository

Everything that contains keys stays on your machine:

- `config.json` — Shadowsocks passwords, REALITY keys, proxy credentials;
- `.env`, `*.log`, `*.pid`;
- certificates and private keys.

They are listed in `.gitignore`. `config.example.json` contains only `YOUR_*`
placeholders.

## What counts as a secret

| File | Contents |
|---|---|
| `config.json` | UUID, SS password, REALITY public key, backup proxies |
| `/etc/x-ui/install-result.env` (server) | panel login, password and API token |
| `/root/reality.txt` (server) | REALITY private key |
| subscription link | access to the server for a client |

If any of this reaches git, do not "delete the file" — **rotate the key**. History keeps
commits, so treat it as compromised.

## Panel on a public IP

The 3x-ui panel is a web application with authentication. Practical rules:

1. non-standard port;
2. TLS with a valid certificate;
3. fail2ban (included in 3x-ui);
4. ideally SSH tunnel only:

```bash
ssh -L 1001:127.0.0.1:1001 root@SERVER_IP
# then open http://127.0.0.1:1001
```

## Boundaries of this scheme

- It changes the address you connect from. It does **not** make you invisible:
  timezone, language, browser fingerprint and payment history remain separate signals.
- If a service demands identity verification, this scheme will not pass it for you.
- A local bypass is possible if a process runs as administrator or ignores the proxy —
  that is why a firewall is needed, not just proxy settings.

## Reporting a problem

Open an issue without logs that contain IPs, UUIDs, keys or domains. If you must show a
config, replace values with `REDACTED`.
