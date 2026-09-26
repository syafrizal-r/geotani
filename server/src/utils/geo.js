// Jarak dua titik koordinat (meter) dengan rumus haversine. Dipakai server
// untuk menghitung ulang jarak absensi sendiri, bukan memercayai angka
// jarak_meter yang dikirim aplikasi.
const EARTH_RADIUS_METER = 6371008.8;

function toRad(deg) {
  return (deg * Math.PI) / 180;
}

function distanceMeter(lat1, lon1, lat2, lon2) {
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_RADIUS_METER * Math.asin(Math.sqrt(a));
}

module.exports = { distanceMeter };
