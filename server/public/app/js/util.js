// Helper bersama: escape HTML, format tanggal WIB, label status, modal, toast.

export function esc(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

export function $(selector, root = document) { return root.querySelector(selector); }
export function $all(selector, root = document) { return [...root.querySelectorAll(selector)]; }

// ---------- Waktu ----------
// Aplikasi Android menyimpan waktu sebagai jam lokal WIB tanpa zona
// (DateTime.toIso8601String(), mis. "2026-09-29T08:05:00.000"). Kolom yang
// diisi server lewat SQLite datetime('now') berformat "2026-09-29 01:05:00"
// dan bernilai UTC. Nilai berakhiran Z/offset sudah jelas zonanya.
export function parseWaktu(s) {
  if (!s) return null;
  if (/Z$|[+-]\d\d:\d\d$/.test(s)) return new Date(s);
  if (/^\d{4}-\d\d-\d\d \d\d:\d\d(:\d\d)?$/.test(s)) return new Date(s.replace(' ', 'T') + 'Z');
  return new Date(s + '+07:00');
}

const TZ = 'Asia/Jakarta';
const BULAN = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
const fmtKey = new Intl.DateTimeFormat('en-CA', { timeZone: TZ, year: 'numeric', month: '2-digit', day: '2-digit' });
const fmtParts = new Intl.DateTimeFormat('en-CA', { timeZone: TZ, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });

function wibParts(d) {
  return Object.fromEntries(fmtParts.formatToParts(d).map((x) => [x.type, x.value]));
}
function asDate(s) {
  const d = typeof s === 'string' ? parseWaktu(s) : s;
  return d && !isNaN(d) ? d : null;
}
/** "29 Sep 2026, 08:05" (WIB) — sama dengan format 'd MMM yyyy, HH:mm' di aplikasi. */
export function formatWaktu(s) {
  const d = asDate(s);
  if (!d) return '–';
  const p = wibParts(d);
  return `${Number(p.day)} ${BULAN[p.month - 1]} ${p.year}, ${p.hour}:${p.minute}`;
}
export function formatTanggal(s) {
  const d = asDate(s);
  if (!d) return '–';
  const p = wibParts(d);
  return `${Number(p.day)} ${BULAN[p.month - 1]} ${p.year}`;
}
/** "YYYY-MM-DD" menurut kalender WIB — untuk filter periode & "hari ini". */
export function tanggalKey(s) {
  const d = typeof s === 'string' ? parseWaktu(s) : s;
  return d && !isNaN(d) ? fmtKey.format(d) : '';
}
export function hariIniKey() { return fmtKey.format(new Date()); }

/** Nilai <input type="datetime-local"> dari string waktu tersimpan (dalam WIB). */
export function toInputDateTime(s) {
  const d = asDate(s);
  if (!d) return '';
  const p = wibParts(d);
  return `${p.year}-${p.month}-${p.day}T${p.hour}:${p.minute}`;
}
/** Kebalikan toInputDateTime: format yang sama dengan yang ditulis aplikasi Android. */
export function fromInputDateTime(v) {
  return v ? `${v.length === 16 ? v + ':00' : v}.000` : '';
}
export function relatif(s) {
  const d = parseWaktu(s);
  const detik = (Date.now() - d.getTime()) / 1000;
  if (detik < 60) return 'baru saja';
  if (detik < 3600) return `${Math.floor(detik / 60)} menit lalu`;
  if (detik < 86400) return `${Math.floor(detik / 3600)} jam lalu`;
  return `${Math.floor(detik / 86400)} hari lalu`;
}

// ---------- Label (sama dengan enum di aplikasi Android) ----------
export const ROLE_LABEL = {
  admin: 'Admin Kepegawaian',
  koordinator: 'Koordinator Penyuluh',
  ppl: 'Penyuluh Pertanian Lapangan',
  kepala_dinas: 'Kepala Dinas',
};
export const SPT_STATUS = {
  menunggu: { label: 'Menunggu Pelaksanaan', cls: 'warn' },
  berlangsung: { label: 'Sedang Berlangsung', cls: 'ok' },
  selesai: { label: 'Selesai', cls: '' },
  ditolak: { label: 'Ditolak', cls: 'bad' },
};
export const TIPE_LABEL = { check_in: 'Check-in', check_out: 'Check-out' };
export const STATUS_ABSENSI = {
  tervalidasi: 'Tervalidasi',
  ditolak_lokasi: 'Ditolak (Di luar lokasi)',
  ditolak_wajah: 'Ditolak (Wajah tidak cocok)',
};
export const APPROVAL_LABEL = { menunggu: 'Menunggu Persetujuan', disetujui: 'Disetujui', ditolak: 'Ditolak' };

export function sptBadge(status) {
  const s = SPT_STATUS[status] || { label: status, cls: '' };
  return `<span class="badge ${s.cls}">${esc(s.label)}</span>`;
}

/** Kategori rekap — sama dengan 4 chip di layar Rekap aplikasi Android. */
export function kategoriAbsensi(a) {
  if (a.status !== 'tervalidasi') return 'ditolak_sistem';
  if (a.approval_status === 'disetujui') return 'disetujui';
  if (a.approval_status === 'ditolak') return 'ditolak_koordinator';
  return 'menunggu';
}
export const KATEGORI = {
  disetujui: { label: 'Disetujui', cls: 'ok' },
  ditolak_koordinator: { label: 'Ditolak Koordinator', cls: 'bad' },
  menunggu: { label: 'Menunggu Approval', cls: 'warn' },
  ditolak_sistem: { label: 'Ditolak Sistem', cls: '' },
};
export function absensiBadge(a) {
  if (a.status !== 'tervalidasi') {
    return `<span class="badge bad">${esc(STATUS_ABSENSI[a.status] || a.status)}</span>`;
  }
  const k = KATEGORI[kategoriAbsensi(a)];
  return `<span class="badge ${k.cls}">${esc(k.label)}</span>`;
}

export function persen(x) { return `${(Number(x) * 100).toFixed(1)}%`; }
export function meter(x) {
  const n = Number(x);
  return n >= 1000 ? `${(n / 1000).toFixed(2)} km` : `${n.toFixed(n < 10 ? 1 : 0)} m`;
}

// ---------- Password ----------
// Harus sama dengan PasswordHasher di aplikasi: SHA-256 hex tanpa salt.
// crypto.subtle hanya ada di konteks aman (HTTPS/localhost); untuk akses
// http://IP-LAN dipakai implementasi JS murni di bawah.
export async function sha256Hex(text) {
  const bytes = new TextEncoder().encode(text);
  if (globalThis.crypto?.subtle) {
    const buf = await crypto.subtle.digest('SHA-256', bytes);
    return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
  }
  return sha256Fallback(bytes);
}

function sha256Fallback(bytes) {
  const K = new Uint32Array([
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ]);
  const H = new Uint32Array([0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]);
  const len = bytes.length;
  const total = Math.ceil((len + 9) / 64) * 64;
  const m = new Uint8Array(total);
  m.set(bytes);
  m[len] = 0x80;
  const dv = new DataView(m.buffer);
  dv.setUint32(total - 8, Math.floor(len / 0x20000000));
  dv.setUint32(total - 4, (len << 3) >>> 0);
  const W = new Uint32Array(64);
  const rotr = (x, n) => (x >>> n) | (x << (32 - n));
  for (let off = 0; off < total; off += 64) {
    for (let i = 0; i < 16; i++) W[i] = dv.getUint32(off + i * 4);
    for (let i = 16; i < 64; i++) {
      const s0 = rotr(W[i - 15], 7) ^ rotr(W[i - 15], 18) ^ (W[i - 15] >>> 3);
      const s1 = rotr(W[i - 2], 17) ^ rotr(W[i - 2], 19) ^ (W[i - 2] >>> 10);
      W[i] = (W[i - 16] + s0 + W[i - 7] + s1) >>> 0;
    }
    let [a, b, c, d, e, f, g, h] = H;
    for (let i = 0; i < 64; i++) {
      const t1 = (h + (rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)) + ((e & f) ^ (~e & g)) + K[i] + W[i]) >>> 0;
      const t2 = ((rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)) + ((a & b) ^ (a & c) ^ (b & c))) >>> 0;
      h = g; g = f; f = e; e = (d + t1) >>> 0; d = c; c = b; b = a; a = (t1 + t2) >>> 0;
    }
    H[0] += a; H[1] += b; H[2] += c; H[3] += d; H[4] += e; H[5] += f; H[6] += g; H[7] += h;
  }
  return [...H].map((x) => x.toString(16).padStart(8, '0')).join('');
}

// ---------- Ikon (garis, 24px) ----------
const P = {
  home: '<path d="M3 11l9-7 9 7"/><path d="M5 10v10h14V10"/>',
  users: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.6-3.6 3.3-5.5 6.5-5.5s5.9 1.9 6.5 5.5"/><path d="M16 4.6a3.5 3.5 0 010 6.8M18 14.8c2 .7 3.2 2.5 3.5 5.2"/>',
  pin: '<path d="M12 21s-7-6.2-7-11.5a7 7 0 0114 0C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
  file: '<path d="M14 3H6v18h12V7z"/><path d="M14 3v4h4M9 12h6M9 16h6"/>',
  check: '<path d="M4 12.5l5 5L20 6.5"/>',
  checkCircle: '<circle cx="12" cy="12" r="9"/><path d="M8 12.5l3 3 5-6"/>',
  chart: '<path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>',
  logout: '<path d="M15 4h4v16h-4M10 8l-4 4 4 4M6 12h10"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13.5 6.5l4 4"/>',
  trash: '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>',
  x: '<path d="M6 6l12 12M18 6L6 18"/>',
  menu: '<path d="M4 7h16M4 12h16M4 17h16"/>',
  download: '<path d="M12 4v11M7 10l5 5 5-5M5 20h14"/>',
  refresh: '<path d="M20 11a8 8 0 10-2.3 5.7M20 5v6h-6"/>',
  eye: '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
};
export function icon(name) {
  return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${P[name] || ''}</svg>`;
}
export const LOGO = '<svg class="logo" viewBox="0 0 32 32" aria-hidden="true"><rect width="32" height="32" rx="8" fill="#2f7d4f"/><path d="M16 25V13m0 0c0-4 3-7 7-7 0 4-3 7-7 7zm0 4c0-3-2.5-5.5-6-5.5 0 3 2.5 5.5 6 5.5z" stroke="#fff" stroke-width="2.2" fill="none" stroke-linecap="round"/></svg>';

// ---------- Toast ----------
export function toast(message, kind = '') {
  const host = document.getElementById('toasts');
  const el = document.createElement('div');
  el.className = `toast ${kind}`;
  el.textContent = message;
  host.appendChild(el);
  setTimeout(() => el.remove(), kind === 'bad' ? 6000 : 3500);
}

// ---------- Modal ----------
/**
 * Membuka modal. `body` berupa HTML; `onMount(modalEl, close)` dipanggil setelah
 * modal ada di DOM. Mengembalikan fungsi close.
 */
export function openModal({ title, body, foot = '', wide = false, onMount, onClose }) {
  const back = document.createElement('div');
  back.className = 'modal-back';
  back.innerHTML = `
    <div class="modal ${wide ? 'wide' : ''}" role="dialog" aria-modal="true" aria-label="${esc(title)}">
      <div class="modal-head"><h2>${esc(title)}</h2><button class="btn ghost icon" data-close aria-label="Tutup">${icon('x')}</button></div>
      <div class="modal-body">${body}</div>
      ${foot ? `<div class="modal-foot">${foot}</div>` : ''}
    </div>`;
  const previousFocus = document.activeElement;
  let closed = false;
  const close = () => {
    if (closed) return;
    closed = true;
    back.remove();
    document.removeEventListener('keydown', onKey);
    previousFocus?.focus?.();
    onClose?.();
  };
  const onKey = (e) => { if (e.key === 'Escape') close(); };
  back.addEventListener('mousedown', (e) => { if (e.target === back) close(); });
  back.querySelectorAll('[data-close]').forEach((b) => b.addEventListener('click', close));
  document.addEventListener('keydown', onKey);
  document.body.appendChild(back);
  onMount?.(back.querySelector('.modal'), close);
  const firstInput = back.querySelector('input:not([type=hidden]), select, textarea');
  (firstInput || back.querySelector('.modal-head button')).focus();
  return close;
}

export function confirmDialog({ title, message, confirmLabel = 'Hapus', danger = true }) {
  return new Promise((resolve) => {
    let result = false;
    openModal({
      title,
      body: `<p style="margin:0">${esc(message)}</p>`,
      foot: `<button class="btn" data-close>Batal</button><button class="btn ${danger ? 'danger solid' : 'primary'}" data-ok>${esc(confirmLabel)}</button>`,
      onMount: (m, close) => {
        const ok = m.querySelector('[data-ok]');
        ok.addEventListener('click', () => { result = true; close(); });
        setTimeout(() => ok.focus(), 0);
      },
      onClose: () => resolve(result),
    });
  });
}

export function byId(list) {
  return new Map(list.map((x) => [x.id, x]));
}
