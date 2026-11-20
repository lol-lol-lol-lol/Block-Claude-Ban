# Architecture

## Principle

Everything reduces to one rule: **Claude domains must have exactly one exit, and that
exit must not be able to fall back to "direct"**.

Most kill switches are criticised for cutting the whole internet. This is the opposite:
only the path to Anthropic is cut, everything else keeps working.

## Flow

```
Claude.app / Chrome / Claude Code
        │  127.0.0.1:2080 (localhost only, not reachable from outside)
        ▼
   sing-box (gateway)
        ├─ domain_suffix: claude.ai, anthropic.com, claude.com,
        │                 claudeusercontent.com, statsig*, sentry*,
        │                 challenges.cloudflare.com
        ├─ ip_cidr: 160.79.104.0/21, 2607:6bc0::/32  (Anthropic networks)
        │        → claude-chain → your server
        └─ everything else → direct (regular VPN or your ISP)
```

`claude-chain` is a `selector`, not `urltest`. There is no automatic failover on
purpose: changing country in the middle of a session looks worse to the service than a
short pause.

## Why Shadowsocks and not only REALITY

Measured in practice: VLESS+REALITY works with Xray clients but **does not survive a
Happ tunnel** — it normalises the ClientHello and the REALITY signature breaks. Plain
TLS passes, and Shadowsocks-2022 passes reliably.

So a typical setup:

| Client | Protocol | Port |
|---|---|---|
| Mac behind a Happ tunnel | Shadowsocks-2022 | 8443 |
| phone, other networks | VLESS + REALITY | 443 |

Both inbounds live in the same panel and are managed from one place.

## DNS

Claude domains are resolved over DoH **inside the tunnel**, not by the local resolver.
This removes DNS spoofing by the ISP and prevents query leaks. Everything else uses the
local resolver as usual.

## Leak protection

1. **Routing.** Anthropic domains have no `direct` option in the chain.
2. **Firewall.** Direct connections to `claude.ai` and `*.anthropic.com` are denied for
   every process (Little Snitch or an equivalent).
3. **Sandbox.** Claude Code runs under `sandbox-exec` with a profile that allows only
   localhost.
4. **Watchdog.** Periodically verifies that Claude Desktop runs with the right proxy and
   restarts it correctly.

## Measurement

- `claude-net trace` — `cloudflare.com/cdn-cgi/trace` via the chain and directly. The
  real answer to "what does Anthropic see".
- `claude-net check` — four points: direct exit, chain exit, `claude.ai`,
  `api.anthropic.com`.

Important: `/cdn-cgi/trace` on `api.anthropic.com` and `claude.ai` returns a **constant**,
not the client address. Never use it to verify a route — use `cloudflare.com` instead.
