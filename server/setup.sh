#!/usr/bin/env bash
# =============================================================================
#  setup.sh -- Feri LAN server: an n2n supernode that relays game LAN traffic
#
#  Players run the FeriLAN app (Windows); all their traffic goes
#  player -> this VPS -> player over UDP, broadcasts included, so the game's
#  LAN list works. A small HTTP service lists who is online for the app.
#
#  Usage:
#    bash <(curl -Ls https://raw.githubusercontent.com/FarzinNs83/feri-lan/main/server/setup.sh)
#  It asks for the host players type in the app (use your domain, e.g.
#  lan.example.com, so a new VPS only needs a DNS change; default: this IP),
#  the port (default 9393) and the password players join with.
#  The password is the n2n community name: the supernode turns away any
#  other, and the app also uses it as the encryption key.
#
#  Ports: UDP+TCP <port> (n2n), TCP <port>+1 (player list).
# =============================================================================
set -Eeuo pipefail

NET=10.88.88
N2N_DEB=https://github.com/ntop/n2n/releases/download/3.1.1/n2n_3.1.1_amd64.deb

say() { printf '[+] %s\n' "$*"; }
die() { printf '[x] %s\n' "$*" >&2; exit 1; }

[[ ${EUID} -eq 0 ]] || die "Run as root (sudo -i first)."

public_ipv4() {
  local ip
  ip=$(ip -4 -o addr show scope global | awk '{split($4, a, "/"); print a[1]}' \
    | grep -vE '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.)' | head -n 1) || true
  [[ -n $ip ]] || ip=$(curl -4 -fsS --max-time 10 https://api.ipify.org) || true
  [[ -n $ip ]] || die "Could not find this server's public IP; pass the host as the first argument."
  printf '%s' "$ip"
}

# ask <question> <default>: the answer, or the default when nobody is at the keyboard (curl | bash reads the script from stdin)
ask() {
  local a=''
  # the prompt goes straight to the tty: read -p writes it to stderr, which is silenced here
  { printf '%s [%s]: ' "$1" "$2" > /dev/tty && read -r a < /dev/tty; } 2> /dev/null || true
  printf '%s' "${a:-$2}"
}

HOST=${1:-}
[[ -n $HOST ]] || HOST=$(ask "Domain or IP players connect to" "$(public_ipv4)")
[[ -n $HOST ]] || die "No host given."

while :; do
  PORT=$(ask "Port" 9393)
  # the player list runs on port + 1
  [[ $PORT =~ ^[0-9]{1,5}$ ]] && ((PORT >= 1 && PORT <= 65534)) && break
  printf '[x] A number from 1 to 65534.
' >&2
done
STATUS_PORT=$((PORT + 1))

# a re-run keeps the old password, so players need not change anything
PASSWORD=$(head -n 1 /etc/n2n/community.list 2> /dev/null || true)
[[ $PASSWORD =~ ^[A-Za-z0-9_-]{6,19}$ ]] || PASSWORD=$(LC_ALL=C tr -dc A-Za-z0-9 < /dev/urandom | head -c 12 || true)
while :; do
  PASSWORD=$(ask "Password players join with (6-19 letters, digits, _ -)" "$PASSWORD")
  # n2n community names stop at 19 characters; this set is safe in community.list and in the app
  [[ $PASSWORD =~ ^[A-Za-z0-9_-]{6,19}$ ]] && break
  printf '[x] 6 to 19 English letters, digits, _ or -.
' >&2
done

# Ubuntu's own n2n package is 1.3 (2008), so the 3.x .deb comes from GitHub, straight or through a GitHub proxy
if ! supernode -h 2>&1 | grep -q 'n2n v.3'; then
  say "Installing n2n 3.1.1 ..."
  rm -f /tmp/n2n.deb
  for u in "$N2N_DEB" "https://ghfast.top/${N2N_DEB}" "https://gh-proxy.com/${N2N_DEB}"; do
    say "Downloading ${u%%/https*} ..."
    # GitHub is often blocked in Iran: give up on a mirror fast instead of hanging silently
    curl -fL -# --connect-timeout 10 --max-time 180 -o /tmp/n2n.deb "$u" && break
    rm -f /tmp/n2n.deb
  done
  [[ -s /tmp/n2n.deb ]] || die "Could not download ${N2N_DEB}. Put it at /tmp/n2n.deb and run again."
  say "Installing packages (apt) ..."
  export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l
  apt-get -o DPkg::Lock::Timeout=180 install -y /tmp/n2n.deb python3     || { apt-get -o DPkg::Lock::Timeout=180 update && apt-get -o DPkg::Lock::Timeout=180 install -y /tmp/n2n.deb python3; }     || die "apt could not install n2n. Check the output above."
  rm -f /tmp/n2n.deb
fi

mkdir -p /etc/n2n

say "Supernode on UDP/TCP ${PORT} ..."
printf '%s\n' "$PASSWORD" > /etc/n2n/community.list
cat > /etc/n2n/supernode.conf << EOF
-p=${PORT}
-c=/etc/n2n/community.list
-a=${NET}.0-${NET}.0/24
EOF
chown -R n2n:n2n /etc/n2n 2> /dev/null || true
systemctl enable -q supernode
systemctl restart supernode

say "Player list on TCP ${STATUS_PORT} ..."
cat > /usr/local/bin/feri-status << EOF
#!/usr/bin/env python3
# Written by setup.sh: the online players (name, LAN IP) as JSON, from the supernode's management port
import http.server, json, socket

def players():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(1)
    s.sendto(b"r 1 edges", ("127.0.0.1", 5645))
    rows = []
    try:
        while True:
            r = json.loads(s.recv(65535))
            if r.get("_type") == "end":
                break
            if r.get("_type") == "row" and r.get("community") == "${PASSWORD}":
                rows.append({"name": r.get("desc", ""), "ip": r.get("ip4addr", "").split("/")[0]})
    except socket.timeout:
        pass
    return rows

class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        b = json.dumps(players()).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def log_message(self, *a):
        pass

http.server.ThreadingHTTPServer(("", ${STATUS_PORT}), H).serve_forever()
EOF
chmod 755 /usr/local/bin/feri-status
cat > /etc/systemd/system/feri-status.service << 'EOF'
[Unit]
Description=FeriLAN player list
After=supernode.service

[Service]
DynamicUser=yes
ExecStart=/usr/local/bin/feri-status
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable -q feri-status
systemctl restart feri-status

if command -v ufw > /dev/null && ufw status 2> /dev/null | grep -q 'Status: active'; then
  ufw allow "${PORT}" > /dev/null
  ufw allow "${STATUS_PORT}/tcp" > /dev/null
fi

cat << EOF

[+] Done. Players add this server in FeriLAN > Settings:

      Server:   ${HOST}
      Port:     ${PORT}
      Password: ${PASSWORD}

    Or send them this invite link; pasted into FeriLAN > Settings > Invite link, it joins at once:

      ferilan://join?host=${HOST}&port=${PORT}&pass=${PASSWORD}

    Open UDP+TCP ${PORT} and TCP ${STATUS_PORT} in your provider's firewall too, if it has one.
EOF
