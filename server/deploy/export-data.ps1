# Kirim database, foto, dan APK dari laptop ke VPS, lalu pasang di sana.
# Jalankan dari PowerShell di folder server:
#   powershell -ExecutionPolicy Bypass -File deploy\export-data.ps1 <IP-VPS>
# Password root VPS akan ditanya 2 kali (kirim file + pasang).
param([Parameter(Mandatory = $true)][string]$Vps)
$ErrorActionPreference = 'Stop'
$server = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$stage = Join-Path $env:TEMP 'geotani-export'
$pkg = Join-Path $env:TEMP 'geotani-import.tgz'

if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory $stage | Out-Null
node (Join-Path $server 'deploy\snapshot-db.js') (Join-Path $stage 'geotani.db')
if ($LASTEXITCODE -ne 0) { throw 'Gagal membuat snapshot database.' }

if (Test-Path $pkg) { Remove-Item $pkg }
tar -czf $pkg -C $stage geotani.db -C $server uploads downloads
if ($LASTEXITCODE -ne 0) { throw 'Gagal membuat arsip.' }
Write-Host ("Arsip siap: {0:N1} MB" -f ((Get-Item $pkg).Length / 1MB))

scp $pkg "root@${Vps}:/root/geotani-import.tgz"
if ($LASTEXITCODE -ne 0) { throw 'Gagal mengirim arsip ke VPS.' }
ssh "root@$Vps" 'rm -rf /root/geotani-import && mkdir /root/geotani-import && tar -xzf /root/geotani-import.tgz -C /root/geotani-import && bash /opt/geotani/server/deploy/import-data.sh'

Remove-Item -Recurse -Force $stage
Remove-Item $pkg
