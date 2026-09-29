import { api, ApiError } from '../api.js';
import {
  esc, icon, formatWaktu, toInputDateTime, fromInputDateTime, sptBadge, absensiBadge, SPT_STATUS, TIPE_LABEL,
  meter, persen, openModal, confirmDialog, toast,
} from '../util.js';
import { createMap, geofence, posisiMarker, fitAll } from '../map.js';
import { loadRefs, ctxFor, openAbsensiModal, foto } from './absensi-detail.js';
import { openForm as openLokasiForm } from './lokasi.js';

export async function render(el, user) {
  const isAdmin = user.role === 'admin';
  let refs = null;
  let query = '';
  let statusFilter = '';

  el.innerHTML = `
    <div class="page-head">
      <div><h1>Surat Perintah Tugas</h1><p>${isAdmin ? 'Penugasan PPL ke lokasi kegiatan.' : 'Daftar penugasan PPL (hanya lihat).'}</p></div>
      ${isAdmin ? `<div class="actions"><button class="btn primary" data-add>${icon('plus')}Tambah SPT</button></div>` : ''}
    </div>
    <section class="card">
      <div class="toolbar">
        <input type="search" placeholder="Cari no. SPT, agenda, PPL, lokasi…" data-q aria-label="Cari SPT">
        <div class="chips" data-chips></div>
      </div>
      <div class="table-wrap" data-table><div class="loading">Memuat…</div></div>
    </section>`;

  const table = el.querySelector('[data-table]');
  const chips = el.querySelector('[data-chips]');

  function drawChips() {
    const count = (s) => refs.sptList.filter((x) => !s || x.status === s).length;
    chips.innerHTML = [['', 'Semua'], ...Object.entries(SPT_STATUS).map(([k, v]) => [k, v.label])]
      .map(([k, label]) => `<button class="chip ${statusFilter === k ? 'active' : ''}" data-status="${k}">${esc(label)} <b>${count(k)}</b></button>`)
      .join('');
  }

  function draw() {
    const q = query.toLowerCase();
    const rows = refs.sptList.filter((s) => {
      if (statusFilter && s.status !== statusFilter) return false;
      if (!q) return true;
      const p = refs.pegawai.get(s.pegawai_id);
      const l = refs.lokasi.get(s.lokasi_id);
      return `${s.nomor_spt} ${s.agenda} ${p?.nama ?? ''} ${l?.nama ?? ''}`.toLowerCase().includes(q);
    });
    drawChips();
    if (!rows.length) {
      table.innerHTML = `<div class="empty">${refs.sptList.length ? 'Tidak ada SPT yang cocok.' : 'Belum ada data SPT.'}</div>`;
      return;
    }
    table.innerHTML = `
      <table class="data stack">
        <thead><tr><th>SPT</th><th>PPL</th><th>Lokasi</th><th>Jadwal</th><th>Status</th><th></th></tr></thead>
        <tbody>${rows.map((s) => {
          const p = refs.pegawai.get(s.pegawai_id);
          const l = refs.lokasi.get(s.lokasi_id);
          return `
          <tr class="click" data-detail="${s.id}">
            <td><div class="cell-main">${esc(s.agenda)}</div><div class="cell-sub">${esc(s.nomor_spt)}</div></td>
            <td data-label="PPL">${esc(p?.nama ?? '–')}</td>
            <td data-label="Lokasi">${esc(l?.nama ?? '–')}</td>
            <td data-label="Jadwal" class="small"><span class="nowrap">${esc(formatWaktu(s.tanggal_mulai))}</span><br><span class="muted nowrap">s.d. ${esc(formatWaktu(s.tanggal_selesai))}</span></td>
            <td data-label="Status">${sptBadge(s.status)}</td>
            <td class="actions">
              <button class="btn ghost icon" data-view="${s.id}" title="Detail" aria-label="Detail ${esc(s.nomor_spt)}">${icon('eye')}</button>
              ${isAdmin ? `
              <button class="btn ghost icon" data-edit="${s.id}" title="Ubah" aria-label="Ubah ${esc(s.nomor_spt)}">${icon('edit')}</button>
              <button class="btn ghost icon danger" data-del="${s.id}" title="Hapus" aria-label="Hapus ${esc(s.nomor_spt)}">${icon('trash')}</button>` : ''}
            </td>
          </tr>`;
        }).join('')}
        </tbody>
      </table>
      <div class="table-foot">${rows.length} dari ${refs.sptList.length} SPT</div>`;
  }

  async function load() {
    refs = await loadRefs();
    draw();
  }

  el.querySelector('[data-q]').addEventListener('input', (e) => { query = e.target.value.trim(); draw(); });
  chips.addEventListener('click', (e) => {
    const c = e.target.closest('[data-status]');
    if (c) { statusFilter = c.dataset.status; draw(); }
  });
  el.querySelector('[data-add]')?.addEventListener('click', () => openForm(null, refs, load));
  table.addEventListener('click', (e) => {
    const find = (attr) => {
      const b = e.target.closest(`[${attr}]`);
      return b ? refs.spt.get(Number(b.getAttribute(attr))) : null;
    };
    const edit = find('data-edit');
    if (edit) return openForm(edit, refs, load);
    const del = find('data-del');
    if (del) return hapus(del, load);
    const s = find('data-view') || find('data-detail');
    if (s) openDetail(s, refs);
  });

  await load();
}

async function hapus(s, reload) {
  // Aturan yang sama dengan SptListScreen di aplikasi Android.
  try {
    const [absensi, laporan] = await Promise.all([api.absensi(`?sptId=${s.id}`), api.laporanBySpt(s.id)]);
    if (absensi.length || laporan) {
      toast(`Tidak dapat menghapus SPT "${s.nomor_spt}" karena sudah memiliki riwayat absensi/laporan.`, 'bad');
      return;
    }
    if (!(await confirmDialog({ title: 'Hapus SPT', message: `Yakin ingin menghapus SPT "${s.nomor_spt}"?` }))) return;
    await api.deleteSpt(s.id);
    toast('SPT dihapus.');
    await reload();
  } catch (e) {
    toast(e.message, 'bad');
  }
}

function openDetail(s, refs) {
  const p = refs.pegawai.get(s.pegawai_id);
  const l = refs.lokasi.get(s.lokasi_id);
  let map = null;
  openModal({
    title: `SPT ${s.nomor_spt}`,
    wide: true,
    body: `
      <div style="display:flex;justify-content:space-between;gap:10px;flex-wrap:wrap;align-items:flex-start">
        <h3 style="font-size:17px">${esc(s.agenda)}</h3>${sptBadge(s.status)}
      </div>
      <div class="grid-2" style="margin-top:14px">
        <dl class="kv">
          <dt>No. SPT</dt><dd>${esc(s.nomor_spt)}</dd>
          <dt>PPL</dt><dd>${esc(p?.nama ?? '–')}<div class="muted small">NIP ${esc(p?.nip ?? '–')}</div></dd>
          <dt>Lokasi</dt><dd>${esc(l?.nama ?? '–')}<div class="muted small">${esc(l?.alamat ?? '')}</div></dd>
          <dt>Radius</dt><dd>${l ? esc(meter(l.radius_meter)) : '–'}</dd>
          <dt>Mulai</dt><dd>${esc(formatWaktu(s.tanggal_mulai))}</dd>
          <dt>Selesai</dt><dd>${esc(formatWaktu(s.tanggal_selesai))}</dd>
        </dl>
        <div class="map" data-map></div>
      </div>
      <div class="section-title">Riwayat absensi</div>
      <div data-absensi class="muted small">Memuat…</div>
      <div class="section-title">Laporan hasil kunjungan</div>
      <div data-laporan class="muted small">Memuat…</div>`,
    onMount: async (m) => {
      if (window.L && l) {
        map = createMap(m.querySelector('[data-map]'), { center: [l.latitude, l.longitude], zoom: 16 });
      }
      const absEl = m.querySelector('[data-absensi]');
      const lapEl = m.querySelector('[data-laporan]');
      try {
        const [absensi, lap] = await Promise.all([api.absensi(`?sptId=${s.id}`), api.laporanBySpt(s.id)]);
        if (map && l) {
          const layers = [geofence(map, l.latitude, l.longitude, l.radius_meter).circle];
          absensi.forEach((a) => layers.push(posisiMarker(map, a.latitude, a.longitude, a.status === 'tervalidasi')
            .bindTooltip(`${TIPE_LABEL[a.tipe]} · ${meter(a.jarak_meter)}`)));
          fitAll(map, layers);
        }
        absEl.classList.remove('muted', 'small');
        absEl.innerHTML = absensi.length ? `
          <div class="card"><ul class="list">${absensi.map((a, i) => `
            <li class="click" data-i="${i}" tabindex="0"><div><b>${esc(TIPE_LABEL[a.tipe] || a.tipe)}</b> <span class="muted">· ${esc(formatWaktu(a.waktu))}</span>
              <div class="muted small">Jarak ${esc(meter(a.jarak_meter))} · wajah ${esc(persen(a.face_similarity))}</div></div>
              ${absensiBadge(a)}</li>`).join('')}</ul></div>`
          : '<span class="muted small">Belum ada absensi untuk SPT ini.</span>';
        absEl.querySelectorAll('li[data-i]').forEach((li) => {
          const open = () => openAbsensiModal(ctxFor(absensi[li.dataset.i], refs));
          li.addEventListener('click', open);
          li.addEventListener('keydown', (e) => { if (e.key === 'Enter') open(); });
        });
        if (!lap) {
          lapEl.textContent = 'PPL belum mengunggah laporan.';
        } else {
          lapEl.classList.remove('muted', 'small');
          lapEl.innerHTML = `<div class="grid-2">
            <div>${foto(lap.foto_path, 'Foto laporan kunjungan')}</div>
            <div><p style="margin:0;white-space:pre-wrap">${esc(lap.catatan)}</p><div class="muted small" style="margin-top:6px">Dibuat ${esc(formatWaktu(lap.waktu_dibuat))}</div></div></div>`;
        }
      } catch (e) {
        absEl.textContent = `Gagal memuat: ${e.message}`;
        lapEl.textContent = '';
      }
    },
    onClose: () => map?.remove(),
  });
}

function openForm(existing, refs, reload) {
  const isEdit = !!existing;
  const ppl = refs.pegawaiList.filter((p) => p.role === 'ppl');
  const now = new Date();
  const mulaiDefault = existing ? toInputDateTime(existing.tanggal_mulai) : toInputDateTime(now);
  const selesaiDefault = existing ? toInputDateTime(existing.tanggal_selesai) : toInputDateTime(new Date(now.getTime() + 8 * 3600e3));
  const lokasiOptions = (selectedId) => refs.lokasiList.map((l) =>
    `<option value="${l.id}" ${l.id === selectedId ? 'selected' : ''}>${esc(l.nama)}</option>`).join('');

  openModal({
    title: isEdit ? 'Ubah SPT' : 'Tambah SPT',
    body: `
      <form id="spt-form" novalidate>
        <div class="form-error" hidden></div>
        <label class="field"><span>No. SPT</span><input name="nomor_spt" value="${esc(existing?.nomor_spt)}" placeholder="mis. 094/SPT/DISTAN/2026" required></label>
        <label class="field"><span>PPL</span>
          <select name="pegawai_id" required><option value="">— Pilih PPL —</option>
            ${ppl.map((p) => `<option value="${p.id}" ${p.id === existing?.pegawai_id ? 'selected' : ''}>${esc(p.nama)}${p.face_embedding ? '' : ' (belum daftar wajah)'}</option>`).join('')}
          </select></label>
        <label class="field"><span>SPT Dalam Rangka Apa</span><textarea name="agenda" rows="2" placeholder="mis. Pendampingan panen padi kelompok tani" required>${esc(existing?.agenda)}</textarea></label>
        <label class="field"><span>Lokasi Tujuan</span>
          <div style="display:flex;gap:8px">
            <select name="lokasi_id" required style="flex:1;min-width:0"><option value="">— Pilih lokasi —</option>${lokasiOptions(existing?.lokasi_id)}</select>
            <button type="button" class="btn" data-new-lokasi>${icon('plus')}Baru</button>
          </div></label>
        <div class="row2">
          <label class="field"><span>Tanggal Mulai</span><input type="datetime-local" name="tanggal_mulai" value="${mulaiDefault}" required></label>
          <label class="field"><span>Tanggal Selesai</span><input type="datetime-local" name="tanggal_selesai" value="${selesaiDefault}" required></label>
        </div>
        <label class="field"><span>Status</span>
          <select name="status">${Object.entries(SPT_STATUS).map(([k, v]) =>
            `<option value="${k}" ${(existing?.status ?? 'menunggu') === k ? 'selected' : ''}>${esc(v.label)}</option>`).join('')}</select>
          <div class="hint">PPL hanya bisa absen saat status "Sedang Berlangsung".</div></label>
      </form>`,
    foot: `<button class="btn" data-close>Batal</button><button class="btn primary" type="submit" form="spt-form">${isEdit ? 'Simpan Perubahan' : 'Tambah SPT'}</button>`,
    onMount: (m, close) => {
      const form = m.querySelector('form');
      const err = m.querySelector('.form-error');
      const submit = m.querySelector('[type=submit]');

      m.querySelector('[data-new-lokasi]').addEventListener('click', () => {
        openLokasiForm(null, null, {
          onSaved: (lokasi) => {
            refs.lokasiList.push(lokasi);
            refs.lokasi.set(lokasi.id, lokasi);
            form.lokasi_id.innerHTML = `<option value="">— Pilih lokasi —</option>${lokasiOptions(lokasi.id)}`;
          },
        });
      });

      form.addEventListener('submit', async (e) => {
        e.preventDefault();
        const v = Object.fromEntries(new FormData(form));
        const problems = [];
        if (!v.nomor_spt.trim()) problems.push('No. SPT wajib diisi');
        if (!v.pegawai_id) problems.push('PPL wajib dipilih');
        if (!v.agenda.trim()) problems.push('Agenda wajib diisi');
        if (!v.lokasi_id) problems.push('Lokasi wajib dipilih');
        if (!v.tanggal_mulai || !v.tanggal_selesai) problems.push('Tanggal mulai dan selesai wajib diisi');
        else if (v.tanggal_selesai <= v.tanggal_mulai) problems.push('Tanggal selesai harus setelah tanggal mulai');
        if (problems.length) {
          err.textContent = problems.join(' · ');
          err.hidden = false;
          return;
        }
        submit.disabled = true;
        try {
          const body = {
            nomor_spt: v.nomor_spt.trim(),
            pegawai_id: Number(v.pegawai_id),
            lokasi_id: Number(v.lokasi_id),
            agenda: v.agenda.trim(),
            tanggal_mulai: fromInputDateTime(v.tanggal_mulai),
            tanggal_selesai: fromInputDateTime(v.tanggal_selesai),
            status: v.status,
          };
          if (isEdit) await api.updateSpt(existing.id, body);
          else await api.createSpt(body);
          close();
          toast(isEdit ? 'Perubahan disimpan.' : 'SPT ditambahkan.');
          await reload();
        } catch (e2) {
          err.textContent = e2 instanceof ApiError && e2.status === 409 ? 'Nomor SPT sudah digunakan.' : e2.message;
          err.hidden = false;
        } finally {
          submit.disabled = false;
        }
      });
    },
  });
}
