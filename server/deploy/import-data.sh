#!/usr/bin/env bash
# Memasang data yang dikirim dari laptop oleh export-data.ps1 (ada di
# /root/geotani-import) ke server. Jalankan di VPS sebagai root:
#   bash /opt/geotani/server/deploy/import-data.sh
set -euo pipefail
SRC=/root/geotani-import
DST=/opt/geotani/server

[ -f "$SRC/geotani.db" ] || { echo "Tidak ada $SRC/geotani.db — jalankan export-data.ps1 di laptop dulu."; exit 1; }

systemctl stop geotani
if [ -f "$DST/data/geotani.db" ]; then
  keep="$DST/data/geotani.sebelum-import-$(date +%Y%m%d-%H%M%S).db"
  mv "$DST/data/geotani.db" "$keep"
  echo "Database lama disimpan sebagai $keep"
fi
rm -f "$DST/data/geotani.db-wal" "$DST/data/geotani.db-shm"
cp "$SRC/geotani.db" "$DST/data/geotani.db"
[ -d "$SRC/uploads" ] && cp -r "$SRC/uploads/." "$DST/uploads/"
[ -d "$SRC/downloads" ] && cp -r "$SRC/downloads/." "$DST/downloads/"
chown -R geotani:geotani "$DST/data" "$DST/uploads" "$DST/downloads"
systemctl start geotani
sleep 2
curl -fsS http://127.0.0.1:3000/api/status | head -c 300; echo
echo "Import selesai."
