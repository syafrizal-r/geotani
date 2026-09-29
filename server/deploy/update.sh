#!/usr/bin/env bash
# Tarik kode terbaru dari GitHub lalu restart server. Jalankan di VPS sebagai root:
#   bash /var/www/geotani/server/deploy/update.sh
set -euo pipefail
cd /var/www/geotani
git pull --ff-only
cd server
/opt/node24/bin/npm ci --omit=dev
pm2 restart geotani
sleep 2
curl -fsS http://127.0.0.1:3011/api/health && echo "  <- server OK"
