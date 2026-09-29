#!/usr/bin/env bash
# Setup server GeoTani di VPS Ubuntu 22.04/24.04 yang masih baru.
# Jalankan sebagai root:
#   curl -fsSL https://raw.githubusercontent.com/syafrizal-r/geotani/main/server/deploy/setup-vps.sh -o setup-vps.sh
#   bash setup-vps.sh geotani.my.id
#
# Hasilnya:
#   - Node.js 24 LTS, kode di /opt/geotani (clone dari GitHub)
#   - service systemd `geotani` (otomatis nyala saat VPS reboot / crash)
#   - Caddy sebagai reverse proxy + HTTPS otomatis (Let's Encrypt) untuk domain
#   - firewall hanya membuka SSH, 80, 443 (port 3000 tidak terbuka ke publik)
#   - backup database harian ke /var/backups/geotani (disimpan 14 hari)
# Aman dijalankan ulang.
set -euo pipefail

DOMAIN="${1:-}"
REPO="https://github.com/syafrizal-r/geotani.git"
APP_DIR=/opt/geotani
SERVER_DIR="$APP_DIR/server"
APP_USER=geotani

if [ -z "$DOMAIN" ]; then
  echo "Pemakaian: bash setup-vps.sh <domain>   contoh: bash setup-vps.sh geotani.my.id"
  exit 1
fi
if [ "$(id -u)" -ne 0 ]; then
  echo "Jalankan sebagai root (atau pakai sudo)."
  exit 1
fi

echo "==> Paket dasar"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl git ufw ca-certificates gnupg debian-keyring debian-archive-keyring apt-transport-https

echo "==> Node.js 24 LTS"
if ! command -v node >/dev/null || [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 24 ]; then
  curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
  apt-get install -y nodejs
fi
node -v

echo "==> Caddy (HTTPS otomatis)"
if ! command -v caddy >/dev/null; then
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' > /etc/apt/sources.list.d/caddy-stable.list
  apt-get update -y
  apt-get install -y caddy
fi

echo "==> User & kode aplikasi"
id "$APP_USER" >/dev/null 2>&1 || useradd --system --create-home --shell /usr/sbin/nologin "$APP_USER"
if [ -d "$APP_DIR/.git" ]; then
  sudo -u "$APP_USER" git -C "$APP_DIR" pull --ff-only
else
  git clone "$REPO" "$APP_DIR"
  chown -R "$APP_USER:$APP_USER" "$APP_DIR"
fi
cd "$SERVER_DIR"
sudo -u "$APP_USER" npm ci --omit=dev
sudo -u "$APP_USER" mkdir -p data uploads/absensi uploads/laporan downloads

if [ ! -f .env ]; then
  echo "==> Membuat .env dengan JWT_SECRET acak"
  printf 'PORT=3000\nJWT_SECRET=%s\n' "$(openssl rand -hex 32)" > .env
  chown "$APP_USER:$APP_USER" .env
  chmod 600 .env
fi

echo "==> Service systemd"
cat > /etc/systemd/system/geotani.service <<EOF
[Unit]
Description=GeoTani REST API
After=network.target

[Service]
User=$APP_USER
WorkingDirectory=$SERVER_DIR
ExecStart=/usr/bin/node src/index.js
Restart=always
RestartSec=3
Environment=NODE_ENV=production
Environment=NODE_NO_WARNINGS=1

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable geotani
systemctl restart geotani

echo "==> Caddy untuk $DOMAIN"
cat > /etc/caddy/Caddyfile <<EOF
$DOMAIN {
	encode gzip
	reverse_proxy 127.0.0.1:3000
}
EOF
systemctl reload caddy || systemctl restart caddy

echo "==> Firewall"
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "==> Backup database harian"
mkdir -p /var/backups/geotani
chown "$APP_USER:$APP_USER" /var/backups/geotani
cat > /etc/cron.daily/geotani-backup <<EOF
#!/bin/sh
sudo -u $APP_USER node $SERVER_DIR/deploy/snapshot-db.js /var/backups/geotani/geotani-\$(date +%F).db >/dev/null 2>&1
find /var/backups/geotani -name 'geotani-*.db' -mtime +14 -delete
EOF
chmod +x /etc/cron.daily/geotani-backup

sleep 2
echo
if curl -fsS http://127.0.0.1:3000/api/health >/dev/null; then
  echo "SELESAI. Server GeoTani jalan."
else
  echo "Server belum merespons, cek log: journalctl -u geotani -n 50"
fi
echo "Buka https://$DOMAIN (sertifikat HTTPS bisa butuh 1-2 menit pertama kali)."
if [ ! -f "$SERVER_DIR/data/geotani.db" ] || [ "$(stat -c %s "$SERVER_DIR/data/geotani.db")" -lt 20000 ]; then
  echo "Database masih kosong. Pindahkan data dari laptop (lihat server/deploy/README.md langkah 5),"
  echo "atau isi data contoh: cd $SERVER_DIR && sudo -u $APP_USER npm run seed"
fi
