import { api } from '../api.js';
import {
  esc, icon, formatWaktu, formatTanggal, tanggalKey, absensiBadge, kategoriAbsensi, KATEGORI, TIPE_LABEL,
  STATUS_ABSENSI, APPROVAL_LABEL, meter, persen, toast,
} from '../util.js';
import { loadRefs, ctxFor, openAbsensiModal } from './absensi-detail.js';
import { exportExcel, exportPdf } from '../export.js';

export async function render(el) {
  const [refs, absensi] = await Promise.all([loadRefs(), api.absensi()]);
  // Sama dengan RekapAbsensiScreen: hanya absensi yang pegawai & SPT-nya masih ada.
  const all = absensi.filter((a) => refs.pegawai.has(a.pegawai_id) && refs.spt.has(a.spt_id));
  const ppl = refs.pegawaiList.filter((p) => p.role === 'ppl');

  const f = { dari: '', sampai: '', pegawai: '', kategori: '', q: '' };

  el.innerHTML = `
    <div class="page-head">
      <div><h1>Rekap Absensi</h1><p>Seluruh absensi PPL beserta hasil validasi sistem dan persetujuan koordinator.</p></div>
      <div class="actions">
        <button class="btn" data-xlsx>${icon('download')}Excel</button>
        <button class="btn" data-pdf>${icon('download')}PDF</button>
      </div>
    </div>
    <section class="card">
      <div class="toolbar">
        <label class="small muted nowrap">Dari <input type="date" data-dari></label>
        <label class="small muted nowrap">s.d. <input type="date" data-sampai></label>
        <select data-pegawai aria-label="Filter PPL"><option value="">Semua PPL</option>
          ${ppl.map((p) => `<option value="${p.id}">${esc(p.nama)}</option>`).join('')}</select>
        <input type="search" placeholder="Cari agenda / no. SPT…" data-q aria-label="Cari">
        <button class="btn ghost" data-reset hidden>Hapus filter</button>
      </div>
      <div class="toolbar"><div class="chips" data-chips></div></div>
      <div class="table-wrap" data-table></div>
    </section>`;

  const table = el.querySelector('[data-table]');
  const chips = el.querySelector('[data-chips]');
  let visible = [];

  function baseFiltered() {
    const q = f.q.toLowerCase();
    return all.filter((a) => {
      const key = tanggalKey(a.waktu);
      if (f.dari && key < f.dari) return false;
      if (f.sampai && key > f.sampai) return false;
      if (f.pegawai && a.pegawai_id !== Number(f.pegawai)) return false;
      if (q) {
        const s = refs.spt.get(a.spt_id);
        if (!`${s.agenda} ${s.nomor_spt}`.toLowerCase().includes(q)) return false;
      }
      return true;
    });
  }

  function draw() {
    const base = baseFiltered();
    visible = f.kategori ? base.filter((a) => kategoriAbsensi(a) === f.kategori) : base;
    const count = (k) => base.filter((a) => kategoriAbsensi(a) === k).length;
    chips.innerHTML = `<button class="chip ${f.kategori ? '' : 'active'}" data-k="">Semua <b>${base.length}</b></button>` +
      Object.entries(KATEGORI).map(([k, v]) => `<button class="chip ${f.kategori === k ? 'active' : ''}" data-k="${k}">${esc(v.label)} <b>${count(k)}</b></button>`).join('');
    el.querySelector('[data-reset]').hidden = !(f.dari || f.sampai || f.pegawai || f.kategori || f.q);

    if (!visible.length) {
      table.innerHTML = `<div class="empty">${all.length ? 'Tidak ada absensi yang cocok dengan filter.' : 'Belum ada data absensi.'}</div>`;
      return;
    }
    table.innerHTML = `
      <table class="data stack">
        <thead><tr><th>PPL</th><th>Agenda SPT</th><th>Tipe</th><th>Waktu</th><th>Jarak</th><th>Wajah</th><th>Status</th></tr></thead>
        <tbody>${visible.map((a, i) => {
          const p = refs.pegawai.get(a.pegawai_id);
          const s = refs.spt.get(a.spt_id);
          return `<tr class="click" data-i="${i}" tabindex="0">
            <td class="cell-main">${esc(p.nama)}</td>
            <td data-label="SPT"><div>${esc(s.agenda)}</div><div class="cell-sub">${esc(s.nomor_spt)}</div></td>
            <td data-label="Tipe" class="nowrap">${esc(TIPE_LABEL[a.tipe] || a.tipe)}</td>
            <td data-label="Waktu" class="nowrap">${esc(formatWaktu(a.waktu))}</td>
            <td data-label="Jarak" class="num nowrap">${esc(meter(a.jarak_meter))}</td>
            <td data-label="Wajah" class="num">${esc(persen(a.face_similarity))}</td>
            <td data-label="Status">${absensiBadge(a)}</td>
          </tr>`;
        }).join('')}</tbody>
      </table>
      <div class="table-foot">${visible.length} absensi ditampilkan · klik baris untuk melihat foto dan posisi</div>`;
  }

  function periodeLabel() {
    if (!f.dari && !f.sampai) return 'Seluruh periode';
    const d = (k) => formatTanggal(`${k}T00:00:00.000`);
    return `${f.dari ? d(f.dari) : 'awal'} - ${f.sampai ? d(f.sampai) : 'sekarang'}`;
  }
  function exportRows() {
    return visible.map((a, i) => [
      String(i + 1),
      refs.pegawai.get(a.pegawai_id).nama,
      refs.spt.get(a.spt_id).agenda,
      TIPE_LABEL[a.tipe] || a.tipe,
      formatWaktu(a.waktu),
      Number(a.jarak_meter).toFixed(1),
      persen(a.face_similarity),
      STATUS_ABSENSI[a.status] || a.status,
      APPROVAL_LABEL[a.approval_status] || a.approval_status,
    ]);
  }
  async function doExport(kind, btn) {
    if (!visible.length) return toast('Tidak ada data untuk diexport.', 'bad');
    btn.disabled = true;
    try {
      if (kind === 'pdf') await exportPdf(exportRows(), periodeLabel(), formatWaktu(new Date()));
      else exportExcel(exportRows(), periodeLabel());
    } catch (e) {
      toast(`Gagal membuat file export: ${e.message}`, 'bad');
    } finally {
      btn.disabled = false;
    }
  }

  const bind = (sel, key, ev = 'change') => el.querySelector(sel).addEventListener(ev, (e) => { f[key] = e.target.value.trim(); draw(); });
  bind('[data-dari]', 'dari');
  bind('[data-sampai]', 'sampai');
  bind('[data-pegawai]', 'pegawai');
  bind('[data-q]', 'q', 'input');
  chips.addEventListener('click', (e) => {
    const c = e.target.closest('[data-k]');
    if (c) { f.kategori = c.dataset.k; draw(); }
  });
  el.querySelector('[data-reset]').addEventListener('click', () => {
    Object.keys(f).forEach((k) => { f[k] = ''; });
    ['[data-dari]', '[data-sampai]', '[data-pegawai]', '[data-q]'].forEach((s) => { el.querySelector(s).value = ''; });
    draw();
  });
  table.addEventListener('click', (e) => {
    const tr = e.target.closest('[data-i]');
    if (tr) openAbsensiModal(ctxFor(visible[tr.dataset.i], refs));
  });
  table.addEventListener('keydown', (e) => { if (e.key === 'Enter') e.target.closest('[data-i]')?.click(); });
  el.querySelector('[data-xlsx]').addEventListener('click', (e) => doExport('xlsx', e.currentTarget));
  el.querySelector('[data-pdf]').addEventListener('click', (e) => doExport('pdf', e.currentTarget));

  draw();
}
