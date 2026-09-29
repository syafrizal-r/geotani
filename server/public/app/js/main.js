import { api, session, setUnauthorizedHandler, ApiError } from './api.js';
import { esc, icon, LOGO, ROLE_LABEL, toast } from './util.js';
import * as beranda from './views/beranda.js';
import * as pegawai from './views/pegawai.js';
import * as lokasi from './views/lokasi.js';
import * as spt from './views/spt.js';
import * as persetujuan from './views/persetujuan.js';
import * as rekap from './views/rekap.js';

// Menu per role. PPL sengaja tidak punya akses web: check-in/out butuh
// kamera, GPS, dan pengenalan wajah on-device di aplikasi Android.
const ROUTES = {
  beranda: { label: 'Beranda', icon: 'home', view: beranda, roles: ['admin', 'koordinator', 'kepala_dinas'] },
  persetujuan: { label: 'Persetujuan', icon: 'checkCircle', view: persetujuan, roles: ['koordinator'] },
  pegawai: { label: 'Pegawai', icon: 'users', view: pegawai, roles: ['admin'] },
  lokasi: { label: 'Lokasi', icon: 'pin', view: lokasi, roles: ['admin'] },
  spt: { label: 'SPT', icon: 'file', view: spt, roles: ['admin', 'koordinator', 'kepala_dinas'] },
  rekap: { label: 'Rekap Absensi', icon: 'chart', view: rekap, roles: ['admin', 'koordinator', 'kepala_dinas'] },
};
const WEB_ROLES = ['admin', 'koordinator', 'kepala_dinas'];

const root = document.getElementById('root');
let currentCleanup = null;
let pendingTimer = null;

setUnauthorizedHandler(() => {
  session.clear();
  toast('Sesi berakhir, silakan login kembali.', 'bad');
  render();
});

function currentRoute() {
  const name = location.hash.replace(/^#\/?/, '').split('?')[0];
  const role = session.user?.role;
  const allowed = Object.keys(ROUTES).filter((k) => ROUTES[k].roles.includes(role));
  return allowed.includes(name) ? name : allowed[0];
}

// ---------- Login ----------
function renderLogin() {
  root.innerHTML = `
    <div class="login-wrap">
      <form class="login-card" novalidate>
        <div class="brand">${LOGO}<div><b>GeoTani Web</b><small>Dinas Pertanian Sumatera Utara</small></div></div>
        <div class="form-error" hidden></div>
        <label class="field"><span>Username</span><input name="username" autocomplete="username" required></label>
        <label class="field"><span>Password</span><input name="password" type="password" autocomplete="current-password" required></label>
        <button class="btn primary" type="submit">Masuk</button>
        <p class="login-foot">Untuk Admin, Koordinator, dan Kepala Dinas.<br>PPL melakukan absensi lewat <a href="/download/GeoTani.apk">aplikasi Android</a>.</p>
      </form>
    </div>`;
  const form = root.querySelector('form');
  const err = form.querySelector('.form-error');
  const btn = form.querySelector('button');
  form.username.focus();
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const username = form.username.value.trim();
    const password = form.password.value;
    if (!username || !password) {
      err.textContent = 'Username dan password wajib diisi.';
      err.hidden = false;
      return;
    }
    btn.disabled = true;
    btn.textContent = 'Memeriksa…';
    try {
      const res = await api.login(username, password);
      if (!WEB_ROLES.includes(res.user.role)) {
        err.textContent = 'Akun PPL tidak dapat masuk ke web. Silakan gunakan aplikasi GeoTani di HP.';
        err.hidden = false;
        return;
      }
      session.set(res.token, res.user);
      location.hash = '#/beranda';
      render();
    } catch (e2) {
      err.textContent = e2 instanceof ApiError ? e2.message : String(e2);
      err.hidden = false;
    } finally {
      btn.disabled = false;
      btn.textContent = 'Masuk';
    }
  });
}

// ---------- Shell ----------
function renderShell() {
  const user = session.user;
  const nav = Object.entries(ROUTES)
    .filter(([, r]) => r.roles.includes(user.role))
    .map(([k, r]) => `<a href="#/${k}" data-route="${k}">${icon(r.icon)}<span>${esc(r.label)}</span>${k === 'persetujuan' ? '<span class="badge count" data-pending hidden></span>' : ''}</a>`)
    .join('');
  root.innerHTML = `
    <div class="shell">
      <header class="topbar">
        <button class="btn ghost icon" data-menu aria-label="Menu">${icon('menu')}</button>
        <div class="brand">${LOGO}<b>GeoTani</b></div>
      </header>
      <aside class="sidebar">
        <div class="brand">${LOGO}<div><b>GeoTani</b><small>${esc(ROLE_LABEL[user.role] || user.role)}</small></div></div>
        <nav class="nav">${nav}</nav>
        <div class="me">
          <div class="who"><b>${esc(user.nama)}</b><span>NIP ${esc(user.nip)}</span></div>
          <button class="btn" data-logout>${icon('logout')}Keluar</button>
        </div>
      </aside>
      <div class="scrim" hidden></div>
      <main class="main" id="view"></main>
    </div>`;

  const shell = root.querySelector('.shell');
  const scrim = root.querySelector('.scrim');
  const setNav = (open) => { shell.classList.toggle('nav-open', open); scrim.hidden = !open; };
  root.querySelector('[data-menu]').addEventListener('click', () => setNav(true));
  scrim.addEventListener('click', () => setNav(false));
  root.querySelectorAll('.nav a').forEach((a) => a.addEventListener('click', () => setNav(false)));
  root.querySelector('[data-logout]').addEventListener('click', () => {
    session.clear();
    location.hash = '';
    render();
  });

  if (user.role === 'koordinator') startPendingBadge();
}

// Koordinator: jumlah absensi menunggu persetujuan di menu, diperbarui 15 detik
// sekali (setara polling di dashboard koordinator aplikasi Android).
async function refreshPendingBadge() {
  const badge = root.querySelector('[data-pending]');
  if (!badge) return;
  try {
    const n = (await api.pendingApproval()).length;
    badge.textContent = n;
    badge.hidden = n === 0;
  } catch { /* badge bukan hal kritis */ }
}
function startPendingBadge() {
  clearInterval(pendingTimer);
  refreshPendingBadge();
  pendingTimer = setInterval(refreshPendingBadge, 15000);
}
window.addEventListener('geotani:pending-changed', refreshPendingBadge);

async function showRoute() {
  const name = currentRoute();
  if (location.hash !== `#/${name}`) history.replaceState(null, '', `#/${name}`);
  root.querySelectorAll('.nav a').forEach((a) => a.classList.toggle('active', a.dataset.route === name));
  const route = ROUTES[name];
  document.title = `${route.label} · GeoTani Web`;
  currentCleanup?.();
  currentCleanup = null;
  const view = document.getElementById('view');
  view.innerHTML = '<div class="loading">Memuat…</div>';
  try {
    currentCleanup = (await route.view.render(view, session.user)) || null;
  } catch (e) {
    view.innerHTML = `<div class="card pad"><b>Gagal memuat halaman.</b><p class="muted">${esc(e.message)}</p><button class="btn" data-retry>${icon('refresh')}Coba lagi</button></div>`;
    view.querySelector('[data-retry]').addEventListener('click', showRoute);
  }
}

function render() {
  currentCleanup?.();
  currentCleanup = null;
  clearInterval(pendingTimer);
  if (!session.token || !WEB_ROLES.includes(session.user?.role)) {
    document.title = 'Masuk · GeoTani Web';
    renderLogin();
    return;
  }
  renderShell();
  showRoute();
}

window.addEventListener('hashchange', () => {
  if (session.token && root.querySelector('.shell')) showRoute();
});

render();

// Segarkan data profil (nama/role bisa diubah admin sejak login terakhir).
if (session.token) {
  api.me().then(({ user }) => {
    const roleChanged = user.role !== session.user?.role;
    session.set(session.token, user);
    if (roleChanged) render();
  }).catch(() => {});
}
