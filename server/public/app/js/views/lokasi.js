import { api } from '../api.js';
import { esc, icon, meter, openModal, confirmDialog, toast } from '../util.js';
import { createMap, geofence } from '../map.js';

const DEFAULT_RADIUS = 100; // AppConstants.defaultRadiusMeter

export async function render(el) {
  let items = [];
  let query = '';
  let overview = null;

  el.innerHTML = `
    <div class="page-head">
      <div><h1>Data Lokasi</h1><p>Titik kelompok tani / lahan beserta radius geofence untuk validasi absensi.</p></div>
      <div class="actions"><button class="btn primary" data-add>${icon('plus')}Tambah Lokasi</button></div>
    </div>
    <div class="grid-2" style="align-items:start">
      <section class="card">
        <div class="toolbar"><input type="search" placeholder="Cari nama atau alamat…" data-q aria-label="Cari lokasi"></div>
        <div class="table-wrap" data-table><div class="loading">Memuat…</div></div>
      </section>
      <section class="card pad"><div class="map tall" data-map></div>
        <div class="muted small" style="margin-top:6px">Klik baris di tabel untuk memusatkan peta ke lokasi tersebut.</div></section>
    </div>`;

  const table = el.querySelector('[data-table]');
  const layers = new Map();

  function drawMap() {
    if (!window.L) return;
    if (!overview) overview = createMap(el.querySelector('[data-map]'));
    layers.forEach((g) => { g.circle.remove(); g.center.remove(); });
    layers.clear();
    for (const l of items) {
      const g = geofence(overview, l.latitude, l.longitude, l.radius_meter);
      g.circle.bindTooltip(`${l.nama} (radius ${meter(l.radius_meter)})`);
      layers.set(l.id, g);
    }
    const circles = [...layers.values()].map((g) => g.circle);
    if (circles.length) overview.fitBounds(L.featureGroup(circles).getBounds().pad(0.2), { maxZoom: 15 });
  }

  function draw() {
    const q = query.toLowerCase();
    const rows = items.filter((l) => !q || `${l.nama} ${l.alamat}`.toLowerCase().includes(q));
    if (!rows.length) {
      table.innerHTML = `<div class="empty">${items.length ? 'Tidak ada lokasi yang cocok.' : 'Belum ada data lokasi.'}</div>`;
      return;
    }
    table.innerHTML = `
      <table class="data stack">
        <thead><tr><th>Lokasi</th><th>Radius</th><th></th></tr></thead>
        <tbody>${rows.map((l) => `
          <tr class="click" data-focus="${l.id}">
            <td><div class="cell-main">${esc(l.nama)}</div><div class="cell-sub">${esc(l.alamat)}</div>
              <div class="cell-sub num">${l.latitude.toFixed(6)}, ${l.longitude.toFixed(6)}</div></td>
            <td data-label="Radius" class="nowrap">${esc(meter(l.radius_meter))}</td>
            <td class="actions">
              <button class="btn ghost icon" data-edit="${l.id}" title="Ubah" aria-label="Ubah ${esc(l.nama)}">${icon('edit')}</button>
              <button class="btn ghost icon danger" data-del="${l.id}" title="Hapus" aria-label="Hapus ${esc(l.nama)}">${icon('trash')}</button>
            </td>
          </tr>`).join('')}
        </tbody>
      </table>
      <div class="table-foot">${rows.length} dari ${items.length} lokasi</div>`;
  }

  async function load() {
    items = await api.lokasi();
    draw();
    drawMap();
  }

  el.querySelector('[data-q]').addEventListener('input', (e) => { query = e.target.value.trim(); draw(); });
  el.querySelector('[data-add]').addEventListener('click', () => openForm(null, load));
  table.addEventListener('click', async (e) => {
    const edit = e.target.closest('[data-edit]');
    const del = e.target.closest('[data-del]');
    if (edit) return openForm(items.find((l) => l.id === Number(edit.dataset.edit)), load);
    if (del) return hapus(items.find((l) => l.id === Number(del.dataset.del)), load);
    const row = e.target.closest('[data-focus]');
    const g = row && layers.get(Number(row.dataset.focus));
    if (g && overview) {
      overview.fitBounds(g.circle.getBounds().pad(0.5), { maxZoom: 17 });
      g.circle.openTooltip();
    }
  });

  await load();
  return () => overview?.remove();
}

async function hapus(l, reload) {
  // Aturan yang sama dengan LokasiListScreen di aplikasi Android.
  try {
    const spt = await api.spt(`?lokasiId=${l.id}`);
    if (spt.length) {
      toast(`Tidak dapat menghapus "${l.nama}" karena masih memiliki SPT terkait.`, 'bad');
      return;
    }
    if (!(await confirmDialog({ title: 'Hapus Lokasi', message: `Yakin ingin menghapus lokasi "${l.nama}"?` }))) return;
    await api.deleteLokasi(l.id);
    toast('Lokasi dihapus.');
    await reload();
  } catch (e) {
    toast(e.message, 'bad');
  }
}

/** Form lokasi dengan peta: klik/geser penanda untuk mengisi koordinat. */
export function openForm(existing, reload, { onSaved } = {}) {
  const isEdit = !!existing;
  let map = null;
  openModal({
    title: isEdit ? 'Ubah Lokasi' : 'Tambah Lokasi',
    wide: true,
    body: `
      <form id="lokasi-form" novalidate>
        <div class="form-error" hidden></div>
        <div class="grid-2" style="gap:18px">
          <div>
            <label class="field"><span>Nama Lokasi</span><input name="nama" value="${esc(existing?.nama)}" placeholder="mis. Kelompok Tani Sido Makmur" required></label>
            <label class="field"><span>Alamat</span><textarea name="alamat" rows="2" required>${esc(existing?.alamat)}</textarea></label>
            <div class="row2">
              <label class="field"><span>Latitude</span><input name="latitude" value="${existing?.latitude ?? ''}" inputmode="decimal" required></label>
              <label class="field"><span>Longitude</span><input name="longitude" value="${existing?.longitude ?? ''}" inputmode="decimal" required></label>
            </div>
            <label class="field"><span>Radius Geofence (meter)</span><input name="radius_meter" type="number" min="1" step="any" value="${existing?.radius_meter ?? DEFAULT_RADIUS}" required>
              <div class="hint">PPL hanya bisa absen jika berada di dalam radius ini.</div></label>
          </div>
          <div>
            <div class="map tall" data-map></div>
            <div class="hint">Klik peta untuk menaruh titik lokasi, atau geser penandanya.</div>
          </div>
        </div>
      </form>`,
    foot: `<button class="btn" data-close>Batal</button><button class="btn primary" type="submit" form="lokasi-form">${isEdit ? 'Simpan Perubahan' : 'Tambah Lokasi'}</button>`,
    onMount: (m, close) => {
      const form = m.querySelector('form');
      const err = m.querySelector('.form-error');
      const submit = m.querySelector('[type=submit]');

      if (window.L) {
        map = createMap(m.querySelector('[data-map]'));
        let marker = null;
        let circle = null;
        const readPos = () => {
          const lat = parseFloat(form.latitude.value);
          const lng = parseFloat(form.longitude.value);
          return Number.isFinite(lat) && Number.isFinite(lng) && Math.abs(lat) <= 90 && Math.abs(lng) <= 180 ? [lat, lng] : null;
        };
        const sync = (fit) => {
          const pos = readPos();
          const r = Math.max(1, parseFloat(form.radius_meter.value) || DEFAULT_RADIUS);
          if (!pos) return;
          if (!marker) {
            marker = L.marker(pos, { draggable: true, icon: L.divIcon({ className: '', html: '<div style="width:18px;height:18px;border-radius:50%;background:#2f7d4f;border:3px solid #fff;box-shadow:0 1px 4px rgba(0,0,0,.4)"></div>', iconSize: [18, 18], iconAnchor: [9, 9] }) }).addTo(map);
            marker.on('drag', () => setPos(marker.getLatLng(), false));
            circle = L.circle(pos, { radius: r, color: '#2f7d4f', weight: 2, fillOpacity: 0.12 }).addTo(map);
          }
          marker.setLatLng(pos);
          circle.setLatLng(pos).setRadius(r);
          if (fit) map.fitBounds(circle.getBounds().pad(0.6), { maxZoom: 17 });
        };
        const setPos = (latlng, fit) => {
          form.latitude.value = latlng.lat.toFixed(6);
          form.longitude.value = latlng.lng.toFixed(6);
          sync(fit);
        };
        map.on('click', (e) => setPos(e.latlng, false));
        ['latitude', 'longitude'].forEach((n) => form[n].addEventListener('change', () => sync(true)));
        form.radius_meter.addEventListener('input', () => sync(false));
        setTimeout(() => sync(true), 80);
      }

      form.addEventListener('submit', async (e) => {
        e.preventDefault();
        const v = Object.fromEntries(new FormData(form));
        const lat = Number(v.latitude);
        const lng = Number(v.longitude);
        const radius = Number(v.radius_meter);
        const problems = [];
        if (!v.nama.trim()) problems.push('Nama wajib diisi');
        if (!v.alamat.trim()) problems.push('Alamat wajib diisi');
        if (!v.latitude.trim() || !Number.isFinite(lat) || Math.abs(lat) > 90) problems.push('Latitude harus angka -90 s.d. 90');
        if (!v.longitude.trim() || !Number.isFinite(lng) || Math.abs(lng) > 180) problems.push('Longitude harus angka -180 s.d. 180');
        if (!Number.isFinite(radius) || radius < 1) problems.push('Radius minimal 1 meter');
        if (problems.length) {
          err.textContent = problems.join(' · ');
          err.hidden = false;
          return;
        }
        submit.disabled = true;
        try {
          const body = { nama: v.nama.trim(), alamat: v.alamat.trim(), latitude: lat, longitude: lng, radius_meter: radius };
          const saved = isEdit ? await api.updateLokasi(existing.id, body) : await api.createLokasi(body);
          close();
          toast(isEdit ? 'Perubahan disimpan.' : 'Lokasi ditambahkan.');
          onSaved?.(saved);
          await reload?.();
        } catch (e2) {
          err.textContent = e2.message;
          err.hidden = false;
        } finally {
          submit.disabled = false;
        }
      });
    },
    onClose: () => map?.remove(),
  });
}
