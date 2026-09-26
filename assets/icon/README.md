# Ikon GeoTani

Ikon dibuat sendiri: pin lokasi putih berisi tunas (Geo + Tani) di atas
gradasi hijau #1B5E20 -> #43A047, garis tanah amber #FFB300.

- `geotani_art.svgfrag` — isi SVG (viewBox 0 0 1024 1024) sumber gambar.
- `geotani_icon.png` — ikon penuh 1024px (latar gradasi, gambar skala 0.86).
- `geotani_icon_foreground.png` — foreground ikon adaptif (transparan,
  skala 0.95; flutter_launcher_icons menambah inset 16% sendiri).

PNG dirender dengan Chrome headless (`--screenshot`, latar transparan).
Setelah mengganti PNG, jalankan: `dart run flutter_launcher_icons`.

Ikon notifikasi terpisah: `android/app/src/main/res/drawable/ic_stat_geotani.xml`
(siluet putih, dijaga dari resource shrinker lewat `res/raw/keep.xml`).
