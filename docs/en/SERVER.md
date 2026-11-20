# Server

## Minimum

- VPS with Ubuntu 22.04/24.04, 1 CPU / 1 GB is enough
- free ports **80** (certificate) and **443**
- a domain whose A record points to the server (for the panel and subscriptions)

## Port layout

| Port | What | Who |
|---|---|---|
| 443 | VLESS + REALITY | clients (phone, other networks) |
| 8443 | Shadowsocks-2022 | Mac behind a Happ tunnel |
| 1001 | 3x-ui panel | you only |
| 2096 | subscription server | client links |

443 is reserved for REALITY on purpose: non-standard ports are throttled faster in
restrictive networks, and REALITY is the most resilient protocol available.

## Node installation

```bash
scp server/install-sg-server.sh root@SERVER_IP:/root/
ssh root@SERVER_IP 'bash /root/install-sg-server.sh'
```

The script:

1. installs sing-box;
2. generates REALITY keys and a UUID;
3. writes `/etc/sing-box/config.json` and a systemd unit;
4. opens the port in ufw;
5. prints a ready `outbound` block for the client.

## 3x-ui panel (optional)

```bash
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
```

Gives a web UI, subscriptions, quotas and multiple inbounds on one server.

**Mandatory afterwards:**

1. change the panel port to a non-standard one;
2. enable TLS (Let's Encrypt) and serve it over https only;
3. block the panel port for everyone except yourself, or use
   `ssh -L 1001:127.0.0.1:1001 root@SERVER_IP`.

## Subscriptions

3x-ui issues a per-client subscription link:

```
https://YOUR_DOMAIN:2096/<subPath>/<subId>
```

Clients (Happ, v2rayNG, Hiddify, Shadowrocket) decode the base64 themselves. The port in
the link is the price of keeping 443 for REALITY.

## Certificate renewal

```bash
certbot certonly --standalone -d panel.example.com
```

plus a deploy hook in `/etc/letsencrypt/renewal-hooks/deploy/` that copies the
certificate where the panel expects it and restarts it.
