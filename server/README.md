# GeoTani server

REST API backend for the GeoTani app. It can run on a laptop (LAN, or public
via ngrok with `start-public.bat`) or on a paid VPS with its own domain and
HTTPS — see [deploy/README.md](deploy/README.md). The app keeps no offline
cache on purpose, so if the server is unreachable the app cannot function.

Opening the server address in a browser (`/`) shows a live status page with
aggregate counts only (no personal data), backed by the public
`GET /api/status` endpoint.

## Setup

```
cd server
npm install
npm run seed     # one-time: creates server/data/geotani.db with dummy accounts
npm start        # or: npm run dev (auto-reload via nodemon)
```

Dummy accounts (all password `password123`): `admin`, `koordinator1`, `ppl1`, `ppl2`, `kadis`.

## Connecting phones

1. Make sure the laptop and every phone/emulator are on the **same WiFi network**.
2. Find the laptop's LAN IP: open a terminal and run `ipconfig`, look for the
   `IPv4 Address` under your active WiFi adapter (e.g. `192.168.1.2`).
3. In the GeoTani app's Server Settings screen, enter `http://<that-ip>:3000`.
4. Tap "Test Connection" — it should hit `GET /api/health` and succeed.

**First-run gotcha**: Windows Defender Firewall will likely prompt to allow
Node.js to accept connections the first time you run `npm start`. You must
allow it on **Private** networks, or phones/emulators on the LAN won't be
able to reach port 3000 at all.

**Your LAN IP can change** between sessions (DHCP) or networks — re-check it
and update the Server Settings screen if phones suddenly can't connect.

## Notes

- Password hashing is intentionally unsalted SHA-256 (not bcrypt), to stay
  byte-for-byte compatible with the Flutter app's existing
  `lib/utils/password_hasher.dart` and the ported seed data.
- Uploaded photos (absensi/laporan) are stored under `server/uploads/` and
  served statically at `/uploads/...`.
- `npm run seed` refuses to run again once the `pegawai` table is non-empty —
  delete `server/data/geotani.db` if you want a totally fresh database.
