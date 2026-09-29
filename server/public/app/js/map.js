// Peta Leaflet + OpenStreetMap. `L` dimuat global dari vendor/leaflet.min.js.

const DEFAULT_CENTER = [3.5952, 98.6722]; // Medan, Sumatera Utara

function css(name) {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
}

export function createMap(el, { center = DEFAULT_CENTER, zoom = 12 } = {}) {
  const map = L.map(el, { scrollWheelZoom: false }).setView(center, zoom);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '&copy; OpenStreetMap',
  }).addTo(map);
  // Modal/panel yang baru tampil belum punya ukuran final saat peta dibuat;
  // ikuti perubahan ukuran wadah supaya tile tidak menyisakan area abu-abu.
  const ro = new ResizeObserver(() => map.invalidateSize());
  ro.observe(el);
  map.on('unload', () => ro.disconnect());
  return map;
}

/** Lingkaran geofence lokasi (titik pusat + radius). */
export function geofence(map, lat, lng, radius) {
  const color = css('--accent') || '#2f7d4f';
  const circle = L.circle([lat, lng], { radius, color, weight: 2, fillOpacity: 0.12 }).addTo(map);
  const center = L.circleMarker([lat, lng], { radius: 5, color, fillColor: color, fillOpacity: 1, weight: 0 }).addTo(map);
  return { circle, center };
}

/** Titik posisi PPL saat absen. */
export function posisiMarker(map, lat, lng, ok) {
  const color = ok ? (css('--info') || '#2d6fd0') : (css('--bad') || '#b3261e');
  return L.circleMarker([lat, lng], { radius: 8, color: '#fff', weight: 2, fillColor: color, fillOpacity: 1 }).addTo(map);
}

export function fitAll(map, layers, maxZoom = 17) {
  const group = L.featureGroup(layers.filter(Boolean));
  if (group.getLayers().length) map.fitBounds(group.getBounds().pad(0.3), { maxZoom });
}
