// Klien REST API GeoTani. Web app disajikan dari server yang sama dengan API,
// jadi semua path relatif ke origin halaman ini.

const TOKEN_KEY = 'geotani.token';
const USER_KEY = 'geotani.user';

export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function storageGet(key) {
  try { return localStorage.getItem(key); } catch { return null; }
}
function storageSet(key, value) {
  try {
    if (value == null) localStorage.removeItem(key);
    else localStorage.setItem(key, value);
  } catch { /* mode privat: sesi hanya bertahan selama tab terbuka */ }
}

let token = storageGet(TOKEN_KEY);
let user = null;
try { user = JSON.parse(storageGet(USER_KEY) || 'null'); } catch { user = null; }

export const session = {
  get token() { return token; },
  get user() { return user; },
  set(newToken, newUser) {
    token = newToken;
    user = newUser;
    storageSet(TOKEN_KEY, newToken);
    storageSet(USER_KEY, newUser ? JSON.stringify(newUser) : null);
  },
  clear() { this.set(null, null); },
};

let onUnauthorized = () => {};
export function setUnauthorizedHandler(fn) { onUnauthorized = fn; }

export async function request(method, path, body) {
  // Header ngrok dipertahankan agar web tetap jalan saat server diakses lewat
  // domain ngrok gratis (tanpa header ini ngrok bisa membalas halaman HTML).
  const headers = { 'ngrok-skip-browser-warning': '1' };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body !== undefined) headers['Content-Type'] = 'application/json';

  let res;
  try {
    res = await fetch(path, {
      method,
      headers,
      body: body !== undefined ? JSON.stringify(body) : undefined,
      cache: 'no-store',
    });
  } catch {
    throw new ApiError(0, 'Tidak bisa terhubung ke server. Periksa koneksi internet.');
  }

  if (res.status === 204) return null;
  let data = null;
  const text = await res.text();
  try { data = text ? JSON.parse(text) : null; } catch { data = null; }

  if (!res.ok) {
    if (res.status === 401 && token) onUnauthorized();
    throw new ApiError(res.status, (data && data.error) || `Permintaan gagal (${res.status}).`);
  }
  return data;
}

export const api = {
  login: (username, password) => request('POST', '/api/auth/login', { username, password }),
  me: () => request('GET', '/api/auth/me'),

  pegawai: () => request('GET', '/api/pegawai'),
  createPegawai: (p) => request('POST', '/api/pegawai', p),
  updatePegawai: (id, p) => request('PUT', `/api/pegawai/${id}`, p),
  deletePegawai: (id) => request('DELETE', `/api/pegawai/${id}`),

  lokasi: () => request('GET', '/api/lokasi'),
  createLokasi: (l) => request('POST', '/api/lokasi', l),
  updateLokasi: (id, l) => request('PUT', `/api/lokasi/${id}`, l),
  deleteLokasi: (id) => request('DELETE', `/api/lokasi/${id}`),

  spt: (query = '') => request('GET', `/api/spt${query}`),
  createSpt: (s) => request('POST', '/api/spt', s),
  updateSpt: (id, s) => request('PUT', `/api/spt/${id}`, s),
  setSptStatus: (id, status) => request('PATCH', `/api/spt/${id}/status`, { status }),
  deleteSpt: (id) => request('DELETE', `/api/spt/${id}`),

  absensi: (query = '') => request('GET', `/api/absensi${query}`),
  pendingApproval: () => request('GET', '/api/absensi?pendingApproval=true'),
  setApproval: (id, status, catatan) => request('PATCH', `/api/absensi/${id}/approval`, { status, catatan }),

  laporanBySpt: (sptId) => request('GET', `/api/laporan?sptId=${sptId}`),
};
