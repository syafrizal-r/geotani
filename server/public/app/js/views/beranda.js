import { api } from '../api.js';
import {
  esc, formatWaktu, relatif, tanggalKey, hariIniKey, absensiBadge, sptBadge, TIPE_LABEL, ROLE_LABEL,
} from '../util.js';
import { loadRefs, ctxFor, openAbsensiModal } from './absensi-detail.js';

export async function render(el, user) {
  const [refs, absensi] = await Promise.all([loadRefs(), api.absensi()]);
  const hariIni = hariIniKey();

  const sptBerlangsung = refs.sptList.filter((s) => s.status === 'berlangsung');
  const absenHariIni = absensi.filter((a) => tanggalKey(a.waktu) === hariIni);
  const tervalidasiHariIni = absenHariIni.filter((a) => a.status === 'tervalidasi').length;
  const menunggu = absensi.filter((a) => a.status === 'tervalidasi' && a.approval_status === 'menunggu').length;
  const ppl = refs.pegawaiList.filter((p) => p.role === 'ppl');
  const pplBelumWajah = ppl.filter((p) => !p.face_embedding).length;

  const salam = (() => {
    const h = Number(new Intl.DateTimeFormat('en', { timeZone: 'Asia/Jakarta', hour: 'numeric', hourCycle: 'h23' }).format(new Date()));
    return h < 11 ? 'Selamat pagi' : h < 15 ? 'Selamat siang' : h < 18 ? 'Selamat sore' : 'Selamat malam';
  })();

  const stat = (label, value, detail, href) => `
    <${href ? `a href="${href}" class="card stat link"` : 'div class="card stat"'}>
      <div class="label">${esc(label)}</div>
      <div class="value">${esc(value)}</div>
      <div class="detail">${esc(detail)}</div>
    </${href ? 'a' : 'div'}>`;

  const terbaru = absensi.slice(0, 8);

  el.innerHTML = `
    <div class="page-head">
      <div><h1>${esc(salam)}, ${esc(user.nama)}</h1><p>${esc(ROLE_LABEL[user.role])} · ${esc(formatWaktu(new Date()))} WIB</p></div>
    </div>

    <section class="stats">
      ${stat('SPT sedang berlangsung', sptBerlangsung.length, `dari ${refs.sptList.length} SPT tercatat`, '#/spt')}
      ${stat('Absen tervalidasi hari ini', tervalidasiHariIni, `${absenHariIni.length} percobaan absen hari ini`, '#/rekap')}
      ${stat('Menunggu persetujuan', menunggu, 'oleh koordinator', user.role === 'koordinator' ? '#/persetujuan' : '#/rekap')}
      ${user.role === 'admin'
        ? stat('Penyuluh (PPL)', ppl.length, pplBelumWajah ? `${pplBelumWajah} belum daftar wajah` : 'semua sudah daftar wajah', '#/pegawai')
        : stat('Total absensi', absensi.length, 'sejak awal pencatatan', '#/rekap')}
    </section>

    <div class="grid-2">
      <section class="card">
        <div class="card-head"><h2>Absensi terbaru</h2><a href="#/rekap" class="small">Lihat rekap</a></div>
        ${terbaru.length ? `<ul class="list">${terbaru.map((a, i) => {
          const p = refs.pegawai.get(a.pegawai_id);
          return `<li class="click" data-i="${i}" tabindex="0">
            <div><b>${esc(p?.nama ?? '–')}</b> <span class="muted">· ${esc(TIPE_LABEL[a.tipe] || a.tipe)}</span>
            <div class="muted small">${esc(relatif(a.waktu))} · ${esc(formatWaktu(a.waktu))}</div></div>
            ${absensiBadge(a)}</li>`;
        }).join('')}</ul>` : '<div class="empty">Belum ada absensi.</div>'}
      </section>

      <section class="card">
        <div class="card-head"><h2>SPT sedang berlangsung</h2><a href="#/spt" class="small">Semua SPT</a></div>
        ${sptBerlangsung.length ? `<ul class="list">${sptBerlangsung.map((s) => {
          const p = refs.pegawai.get(s.pegawai_id);
          const l = refs.lokasi.get(s.lokasi_id);
          return `<li><div><b>${esc(s.agenda)}</b>
            <div class="muted small">${esc(p?.nama ?? '–')} · ${esc(l?.nama ?? '–')}</div>
            <div class="muted small">s.d. ${esc(formatWaktu(s.tanggal_selesai))}</div></div>
            ${sptBadge(s.status)}</li>`;
        }).join('')}</ul>` : '<div class="empty">Tidak ada SPT yang sedang berlangsung.</div>'}
      </section>
    </div>`;

  el.querySelectorAll('li[data-i]').forEach((li) => {
    const open = () => openAbsensiModal(ctxFor(terbaru[li.dataset.i], refs));
    li.addEventListener('click', open);
    li.addEventListener('keydown', (e) => { if (e.key === 'Enter') open(); });
  });
}
