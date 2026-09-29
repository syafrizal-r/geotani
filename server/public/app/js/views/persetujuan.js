import { api } from '../api.js';
import { esc, icon, formatWaktu, relatif, TIPE_LABEL, meter, persen, toast } from '../util.js';
import { loadRefs, ctxFor, renderAbsensiDetail } from './absensi-detail.js';

const POLL_MS = 15000;

export async function render(el) {
  let refs = await loadRefs();
  let pending = [];
  let selectedId = null;
  let detailCleanup = null;
  let saving = false;

  el.innerHTML = `
    <div class="page-head">
      <div><h1>Persetujuan Absensi</h1><p>Absensi yang lolos validasi GPS + wajah dan menunggu keputusan Anda. Diperbarui otomatis.</p></div>
      <div class="actions"><button class="btn" data-refresh>${icon('refresh')}Muat ulang</button></div>
    </div>
    <div class="split">
      <section class="card"><div class="card-head"><h2>Menunggu <span class="badge warn" data-count>0</span></h2></div><div data-list><div class="loading">Memuat…</div></div></section>
      <section class="card approval-detail" data-panel><div class="empty">Pilih absensi di sebelah kiri untuk ditinjau.</div></section>
    </div>`;

  const listEl = el.querySelector('[data-list]');
  const panel = el.querySelector('[data-panel]');

  function drawList() {
    el.querySelector('[data-count]').textContent = pending.length;
    if (!pending.length) {
      listEl.innerHTML = '<div class="empty">Tidak ada absensi yang menunggu persetujuan saat ini.</div>';
      return;
    }
    listEl.innerHTML = `<ul class="list">${pending.map((a) => {
      const p = refs.pegawai.get(a.pegawai_id);
      const s = refs.spt.get(a.spt_id);
      return `<li class="click" data-id="${a.id}" tabindex="0" ${a.id === selectedId ? 'style="background:var(--accent-soft)"' : ''}>
        <div style="min-width:0"><b>${esc(p?.nama ?? '–')}</b> <span class="muted">· ${esc(TIPE_LABEL[a.tipe] || a.tipe)}</span>
          <div class="muted small" style="overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(s?.agenda ?? '')}</div>
          <div class="muted small">${esc(formatWaktu(a.waktu))} · ${esc(relatif(a.waktu))}</div></div>
        <div class="small num" style="text-align:right">${esc(meter(a.jarak_meter))}<br>${esc(persen(a.face_similarity))}</div>
      </li>`;
    }).join('')}</ul>`;
  }

  function drawPanel() {
    detailCleanup?.();
    detailCleanup = null;
    const a = pending.find((x) => x.id === selectedId);
    if (!a) {
      panel.innerHTML = `<div class="empty">${pending.length ? 'Pilih absensi di sebelah kiri untuk ditinjau.' : 'Semua absensi sudah ditinjau.'}</div>`;
      return;
    }
    panel.innerHTML = `
      <div class="card-head"><h2>Tinjau Absensi</h2></div>
      <div style="padding:18px" data-detail></div>
      <div style="padding:0 18px 18px">
        <label class="field"><span>Catatan persetujuan (opsional)</span><textarea data-catatan rows="2" placeholder="mis. OK, lokasi sesuai"></textarea></label>
        <div style="display:flex;gap:8px;justify-content:flex-end;flex-wrap:wrap">
          <button class="btn danger" data-decide="ditolak">${icon('x')}Tolak</button>
          <button class="btn primary" data-decide="disetujui">${icon('check')}Setujui</button>
        </div>
        <div class="hint" style="text-align:right">Disetujui → status SPT menjadi Selesai · Ditolak → status SPT menjadi Ditolak</div>
      </div>`;
    detailCleanup = renderAbsensiDetail(panel.querySelector('[data-detail]'), ctxFor(a, refs));
    panel.querySelectorAll('[data-decide]').forEach((b) =>
      b.addEventListener('click', () => decide(a, b.dataset.decide)));
  }

  async function decide(a, status) {
    if (saving) return;
    saving = true;
    panel.querySelectorAll('[data-decide]').forEach((b) => { b.disabled = true; });
    const catatan = panel.querySelector('[data-catatan]').value.trim() || null;
    try {
      await api.setApproval(a.id, status, catatan);
      // Sama dengan ApprovalDetailScreen: keputusan koordinator langsung
      // mencerminkan status SPT di dashboard PPL.
      await api.setSptStatus(a.spt_id, status === 'disetujui' ? 'selesai' : 'ditolak');
      const nama = refs.pegawai.get(a.pegawai_id)?.nama ?? 'PPL';
      toast(`${TIPE_LABEL[a.tipe]} ${nama} ${status === 'disetujui' ? 'disetujui' : 'ditolak'}.`);
      const idx = pending.findIndex((x) => x.id === a.id);
      pending.splice(idx, 1);
      selectedId = pending[Math.min(idx, pending.length - 1)]?.id ?? null;
      drawList();
      drawPanel();
      window.dispatchEvent(new Event('geotani:pending-changed'));
    } catch (e) {
      toast(e.message, 'bad');
      panel.querySelectorAll('[data-decide]').forEach((b) => { b.disabled = false; });
    } finally {
      saving = false;
    }
  }

  async function load({ quiet = false } = {}) {
    const fresh = await api.pendingApproval();
    // Absensi baru bisa merujuk SPT/pegawai yang belum ada di cache.
    if (fresh.some((a) => !refs.spt.has(a.spt_id) || !refs.pegawai.has(a.pegawai_id))) refs = await loadRefs();
    const before = new Set(pending.map((a) => a.id));
    const added = fresh.filter((a) => !before.has(a.id)).length;
    pending = fresh;
    if (!pending.some((a) => a.id === selectedId)) selectedId = window.innerWidth > 1000 ? pending[0]?.id ?? null : null;
    drawList();
    // Panel tidak digambar ulang saat polling kalau pilihan tetap sama, supaya
    // catatan yang sedang diketik tidak hilang.
    if (!quiet || !panel.querySelector('[data-detail]') || !pending.some((a) => a.id === selectedId)) drawPanel();
    if (quiet && added > 0) toast(`${added} absensi baru menunggu persetujuan.`);
  }

  listEl.addEventListener('click', (e) => {
    const li = e.target.closest('[data-id]');
    if (!li) return;
    selectedId = Number(li.dataset.id);
    drawList();
    drawPanel();
    if (window.innerWidth <= 1000) panel.scrollIntoView({ behavior: 'smooth', block: 'start' });
  });
  listEl.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') e.target.closest('[data-id]')?.click();
  });
  el.querySelector('[data-refresh]').addEventListener('click', () => load().catch((e) => toast(e.message, 'bad')));

  await load();
  const timer = setInterval(() => { if (!saving) load({ quiet: true }).catch(() => {}); }, POLL_MS);
  return () => { clearInterval(timer); detailCleanup?.(); };
}
