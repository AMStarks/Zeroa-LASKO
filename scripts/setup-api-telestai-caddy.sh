#!/usr/bin/env bash
# Run on the Switchboard host (Ubuntu) that serves the app on 127.0.0.1:8000.
# DNS for api.telestai.io must already point here (or through Cloudflare to this host).
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Re-run as root: sudo bash $0"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl

# Official Caddy apt repo
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
  | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
  | tee /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy

install -d -m 755 /etc/caddy
cat >/etc/caddy/Caddyfile <<'EOF'
api.telestai.io {
	reverse_proxy 127.0.0.1:8000
}
EOF

# Ensure the Switchboard process is listening on :8000 before enabling public HTTPS.
if ! ss -lnt | grep -q ':8000'; then
  echo "WARNING: nothing is listening on 127.0.0.1:8000 yet."
  echo "Start your Switchboard API first, then: systemctl reload caddy"
fi

if command -v ufw >/dev/null 2>&1; then
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw status || true
fi

systemctl enable caddy
systemctl restart caddy
systemctl --no-pager --full status caddy || true

echo
echo "Done. Caddy terminates TLS for api.telestai.io and proxies HTTP+WebSocket to :8000."
echo "If you use Cloudflare orange-cloud, set SSL/TLS mode to Full (strict) once this cert is issued,"
echo "or use Full with a Cloudflare Origin Certificate."
