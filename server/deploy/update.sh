#!/usr/bin/env bash
# Tarik kode terbaru dari GitHub lalu restart server. Jalankan di VPS sebagai root:
#   bash /opt/geotani/server/deploy/update.sh
set -euo pipefail
cd /opt/geotani
sudo -u geotani git pull --ff-only
cd server
sudo -u geotani npm ci --omit=dev
systemctl restart geotani
sleep 2
curl -fsS http://127.0.0.1:3000/api/health && echo "  <- server OK"
