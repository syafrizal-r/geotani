import { api } from '../api.js';
import {
  esc, formatWaktu, meter, persen, absensiBadge, TIPE_LABEL, STATUS_ABSENSI, APPROVAL_LABEL, openModal,
} from '../util.js';
import { createMap, geofence, posisiMarker, fitAll } from '../map.js';

const FACE_THRESHOLD = 0.75; // sama dengan faceMatchThreshold server & aplikasi

export function foto(path, alt) {
  return path
    ? `<a href="${esc(path)}" target="_blank" rel="noopener"><img class="photo" src="${esc(path)}" alt="${esc(alt)}" loading="lazy"
        onerror="this.parentElement.outerHTML='<div class=&quot;photo-missing&quot;>Foto tidak dapat dimuat</div>'"></a>`
    : '<div class="photo-missing">Tidak ada foto</div>';
}

/**
 * Isi detail satu absensi (identitas, validasi GPS + wajah, foto, peta, laporan).
 * Mengembalikan fungsi cleanup untuk peta.
 */
export function renderAbsensiDetail(el, { absensi: a, pegawai, spt, lokasi, penyetuju }) {
  const ok = a.status === 'tervalidasi';
  const dalamRadius = lokasi ? a.jarak_meter <= lokasi.radius_meter : null;
  const wajahOk = a.face_similarity >= FACE_THRESHOLD;
  el.innerHTML = `
    <div style="display:flex;flex-wrap:wrap;align-items:center;justify-content:space-between;gap:8px">
      <div>
        <h3 style="font-size:17px">${esc(pegawai?.nama ?? 'Pegawai tidak ditemukan')}</h3>
        <div class="muted small">NIP ${esc(pegawai?.nip ?? '–')}</div>
      </div>
      ${absensiBadge(a)}
    </div>

    <div class="section-title">Absensi</div>
    <dl class="kv">
      <dt>Jenis</dt><dd>${esc(TIPE_LABEL[a.tipe] || a.tipe)}</dd>
      <dt>Waktu</dt><dd>${esc(formatWaktu(a.waktu))} WIB</dd>
      <dt>SPT</dt><dd>${esc(spt?.nomor_spt ?? '–')}<div class="muted small">${esc(spt?.agenda ?? '')}</div></dd>
      <dt>Lokasi</dt><dd>${esc(lokasi?.nama ?? '–')}</dd>
    </dl>

    <div class="section-title">Validasi sistem</div>
    <dl class="kv">
      <dt>Jarak ke lokasi</dt>
      <dd>${esc(meter(a.jarak_meter))}${lokasi ? ` <span class="muted small">(radius ${esc(meter(lokasi.radius_meter))})</span>` : ''}
        ${dalamRadius == null ? '' : `<span class="badge ${dalamRadius ? 'ok' : 'bad'}" style="margin-left:4px">${dalamRadius ? 'Dalam radius' : 'Di luar radius'}</span>`}</dd>
      <dt>Kemiripan wajah</dt>
      <dd>${esc(persen(a.face_similarity))} <span class="muted small">(minimal ${persen(FACE_THRESHOLD)})</span>
        <div class="meter ${wajahOk ? '' : 'bad'}" style="max-width:220px"><i style="width:${Math.max(0, Math.min(100, a.face_similarity * 100))}%"></i></div></dd>
      <dt>Hasil</dt><dd>${esc(STATUS_ABSENSI[a.status] || a.status)}</dd>
      ${ok ? `<dt>Persetujuan</dt><dd>${esc(APPROVAL_LABEL[a.approval_status] || a.approval_status)}${
        a.approval_waktu ? `<div class="muted small">${esc(penyetuju?.nama ?? '')}${penyetuju ? ' · ' : ''}${esc(formatWaktu(a.approval_waktu))}</div>` : ''}${
        a.approval_catatan ? `<div class="small">"${esc(a.approval_catatan)}"</div>` : ''}</dd>` : ''}
    </dl>

    <div class="grid-2" style="margin-top:16px">
      <div><div class="section-title" style="margin-top:0">Foto absensi</div>${foto(a.foto_path, 'Foto wajah saat absensi')}</div>
      <div><div class="section-title" style="margin-top:0">Posisi</div><div class="map" data-map></div>
        <div class="muted small" style="margin-top:4px">Lingkaran hijau: radius lokasi · titik ${ok ? 'biru' : 'merah'}: posisi PPL</div></div>
    </div>

    <div class="section-title">Laporan hasil kunjungan</div>
    <div data-laporan class="muted small">Memuat laporan…</div>`;

  let map = null;
  const mapEl = el.querySelector('[data-map]');
  if (window.L) {
    map = createMap(mapEl);
    const layers = [];
    if (lokasi) layers.push(geofence(map, lokasi.latitude, lokasi.longitude, lokasi.radius_meter).circle);
    layers.push(posisiMarker(map, a.latitude, a.longitude, ok));
    fitAll(map, layers);
  } else {
    mapEl.outerHTML = '<div class="photo-missing">Peta tidak tersedia</div>';
  }

  const laporanEl = el.querySelector('[data-laporan]');
  if (spt) {
    api.laporanBySpt(spt.id).then((lap) => {
      if (!laporanEl.isConnected) return;
      if (!lap) {
        laporanEl.textContent = 'PPL belum mengunggah laporan hasil kunjungan.';
        return;
      }
      laporanEl.classList.remove('muted', 'small');
      laporanEl.innerHTML = `
        <div class="grid-2">
          <div>${foto(lap.foto_path, 'Foto laporan kunjungan')}</div>
          <div><p style="margin:0;white-space:pre-wrap">${esc(lap.catatan)}</p>
          <div class="muted small" style="margin-top:6px">Dibuat ${esc(formatWaktu(lap.waktu_dibuat))}</div></div>
        </div>`;
    }).catch(() => { laporanEl.textContent = 'Gagal memuat laporan.'; });
  } else {
    laporanEl.textContent = '–';
  }

  return () => map?.remove();
}

/** Detail absensi dalam modal (read-only). */
export function openAbsensiModal(ctx) {
  let cleanup = null;
  openModal({
    title: 'Detail Absensi',
    wide: true,
    body: '<div data-detail></div>',
    onMount: (m) => { cleanup = renderAbsensiDetail(m.querySelector('[data-detail]'), ctx); },
    onClose: () => cleanup?.(),
  });
}

/** Memuat semua data referensi untuk menampilkan absensi beserta relasinya. */
export async function loadRefs() {
  const [pegawai, spt, lokasi] = await Promise.all([api.pegawai(), api.spt(), api.lokasi()]);
  return {
    pegawai: new Map(pegawai.map((p) => [p.id, p])),
    spt: new Map(spt.map((s) => [s.id, s])),
    lokasi: new Map(lokasi.map((l) => [l.id, l])),
    pegawaiList: pegawai,
    sptList: spt,
    lokasiList: lokasi,
  };
}

export function ctxFor(a, refs) {
  const spt = refs.spt.get(a.spt_id);
  return {
    absensi: a,
    pegawai: refs.pegawai.get(a.pegawai_id),
    spt,
    lokasi: spt ? refs.lokasi.get(spt.lokasi_id) : null,
    penyetuju: a.approval_oleh_id ? refs.pegawai.get(a.approval_oleh_id) : null,
  };
}
