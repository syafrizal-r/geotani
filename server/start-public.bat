@echo off
REM Menyalakan server GeoTani + tunnel ngrok supaya HP bisa akses dari
REM jaringan mana saja (data seluler / WiFi berbeda) lewat
REM https://gulp-composed-retiring.ngrok-free.dev
REM Tutup kedua jendela yang terbuka untuk mematikan.
cd /d "%~dp0"
start "GeoTani Server" cmd /k npm start
timeout /t 3 /nobreak >nul
start "ngrok" cmd /k ngrok http --url=gulp-composed-retiring.ngrok-free.dev 3000
