import { api, session, ApiError } from '../api.js';
import { esc, icon, ROLE_LABEL, openModal, confirmDialog, toast, sha256Hex } from '../util.js';

export async function render(el) {
  let items = [];
  let query = '';
  let roleFilter = '';

  el.innerHTML = `
    <div class="page-head">
      <div><h1>Data Pegawai</h1><p>Akun untuk login di aplikasi Android dan web.</p></div>
      <div class="actions"><button class="btn primary" data-add>${icon('plus')}Tambah Pegawai</button></div>
    </div>
    <section class="card">
      <div class="toolbar">
        <input type="search" placeholder="Cari nama, NIP, username…" data-q aria-label="Cari pegawai">
        <select data-role aria-label="Filter peran">
          <option value="">Semua peran</option>
          ${Object.entries(ROLE_LABEL).map(([k, v]) => `<option value="${k}">${esc(v)}</option>`).join('')}
        </select>
      </div>
      <div class="table-wrap" data-table><div class="loading">Memuat…</div></div>
    </section>`;

  const table = el.querySelector('[data-table]');

  function draw() {
    const q = query.toLowerCase();
    const rows = items.filter((p) =>
      (!roleFilter || p.role === roleFilter) &&
      (!q || `${p.nama} ${p.nip} ${p.username}`.toLowerCase().includes(q)));
    if (!rows.length) {
      table.innerHTML = `<div class="empty">${items.length ? 'Tidak ada pegawai yang cocok.' : 'Belum ada data pegawai.'}</div>`;
      return;
    }
    table.innerHTML = `
      <table class="data stack">
        <thead><tr><th>Nama</th><th>NIP</th><th>Username</th><th>Peran</th><th>Data wajah</th><th></th></tr></thead>
        <tbody>${rows.map((p) => `
          <tr>
            <td><span class="cell-main">${esc(p.nama)}</span>${p.id === session.user.id ? ' <span class="badge info">Anda</span>' : ''}</td>
            <td data-label="NIP" class="num">${esc(p.nip)}</td>
            <td data-label="Username">${esc(p.username)}</td>
            <td data-label="Peran">${esc(ROLE_LABEL[p.role] || p.role)}</td>
            <td data-label="Data wajah">${p.role === 'ppl'
              ? (p.face_embedding ? '<span class="badge ok">Terdaftar</span>' : '<span class="badge warn">Belum</span>')
              : '<span class="muted">–</span>'}</td>
            <td class="actions">
              <button class="btn ghost icon" data-edit="${p.id}" title="Ubah" aria-label="Ubah ${esc(p.nama)}">${icon('edit')}</button>
              <button class="btn ghost icon danger" data-del="${p.id}" title="Hapus" aria-label="Hapus ${esc(p.nama)}">${icon('trash')}</button>
            </td>
          </tr>`).join('')}
        </tbody>
      </table>
      <div class="table-foot">${rows.length} dari ${items.length} pegawai</div>`;
  }

  async function load() {
    items = await api.pegawai();
    draw();
  }

  el.querySelector('[data-q]').addEventListener('input', (e) => { query = e.target.value.trim(); draw(); });
  el.querySelector('[data-role]').addEventListener('change', (e) => { roleFilter = e.target.value; draw(); });
  el.querySelector('[data-add]').addEventListener('click', () => openForm(null, load));
  table.addEventListener('click', async (e) => {
    const edit = e.target.closest('[data-edit]');
    const del = e.target.closest('[data-del]');
    if (edit) openForm(items.find((p) => p.id === Number(edit.dataset.edit)), load);
    if (del) await hapus(items.find((p) => p.id === Number(del.dataset.del)), load);
  });

  await load();
}

async function hapus(p, reload) {
  // Aturan yang sama dengan PegawaiListScreen di aplikasi Android.
  if (p.id === session.user.id) {
    toast('Tidak dapat menghapus akun yang sedang digunakan.', 'bad');
    return;
  }
  try {
    const spt = await api.spt(`?pegawaiId=${p.id}`);
    if (spt.length) {
      toast(`Tidak dapat menghapus "${p.nama}" karena masih memiliki SPT terkait.`, 'bad');
      return;
    }
    if (!(await confirmDialog({ title: 'Hapus Pegawai', message: `Yakin ingin menghapus pegawai "${p.nama}"?` }))) return;
    await api.deletePegawai(p.id);
    toast('Pegawai dihapus.');
    await reload();
  } catch (e) {
    toast(e.message, 'bad');
  }
}

function openForm(existing, reload) {
  const isEdit = !!existing;
  openModal({
    title: isEdit ? 'Ubah Pegawai' : 'Tambah Pegawai',
    body: `
      <form id="pegawai-form" novalidate>
        <div class="form-error" hidden></div>
        <label class="field"><span>NIP</span><input name="nip" value="${esc(existing?.nip)}" inputmode="numeric" required></label>
        <label class="field"><span>Nama</span><input name="nama" value="${esc(existing?.nama)}" required></label>
        <div class="row2">
          <label class="field"><span>Username</span><input name="username" value="${esc(existing?.username)}" autocomplete="off" required></label>
          <label class="field"><span>${isEdit ? 'Password baru' : 'Password'}</span>
            <input name="password" type="password" autocomplete="new-password" ${isEdit ? '' : 'required'}>
            ${isEdit ? '<div class="hint">Kosongkan jika tidak diubah</div>' : ''}</label>
        </div>
        <label class="field"><span>Peran</span>
          <select name="role">${Object.entries(ROLE_LABEL).map(([k, v]) =>
            `<option value="${k}" ${(existing?.role ?? 'ppl') === k ? 'selected' : ''}>${esc(v)}</option>`).join('')}</select>
        </label>
      </form>`,
    foot: `<button class="btn" data-close>Batal</button><button class="btn primary" type="submit" form="pegawai-form">${isEdit ? 'Simpan Perubahan' : 'Tambah Pegawai'}</button>`,
    onMount: (m, close) => {
      const form = m.querySelector('form');
      const err = m.querySelector('.form-error');
      const submit = m.querySelector('[type=submit]');
      form.addEventListener('submit', async (e) => {
        e.preventDefault();
        const v = Object.fromEntries(new FormData(form));
        const missing = [['nip', 'NIP'], ['nama', 'Nama'], ['username', 'Username']]
          .filter(([k]) => !v[k].trim()).map(([, l]) => l);
        if (!isEdit && !v.password) missing.push('Password');
        if (missing.length) {
          err.textContent = `${missing.join(', ')} wajib diisi.`;
          err.hidden = false;
          return;
        }
        submit.disabled = true;
        try {
          const body = {
            nip: v.nip.trim(),
            nama: v.nama.trim(),
            username: v.username.trim(),
            role: v.role,
            // Server menyimpan hash apa adanya; kosong saat edit = password lama dipertahankan.
            password_hash: v.password.trim() ? await sha256Hex(v.password.trim()) : '',
          };
          if (isEdit) await api.updatePegawai(existing.id, body);
          else await api.createPegawai(body);
          if (isEdit && existing.id === session.user.id) {
            const { password_hash, ...profil } = body;
            session.set(session.token, { ...session.user, ...profil });
          }
          close();
          toast(isEdit ? 'Perubahan disimpan.' : 'Pegawai ditambahkan.');
          await reload();
        } catch (e2) {
          err.textContent = e2 instanceof ApiError && e2.status === 409 ? 'NIP atau username sudah digunakan pegawai lain.' : e2.message;
          err.hidden = false;
        } finally {
          submit.disabled = false;
        }
      });
    },
  });
}
