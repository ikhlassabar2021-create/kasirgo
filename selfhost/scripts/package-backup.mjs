#!/usr/bin/env node
// Bundle paket backup self-host (Duplicator-style) menjadi satu ZIP.
//
// Paket berisi:
//   database/   file SQL hasil `dump-database.sh`
//   app/web/    build web Flutter (kasirgo/build/web)
//   app/admin/  build React admin (kasirgo-admin/dist)
//   installer/  server restore + wizard (selfhost/installer)
//
// Jalankan setelah `dump-database.sh` dan build web & admin selesai.
import { cp, readdir, stat, writeFile, rm, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..', '..'); // repo root
const SELFHOST = join(ROOT, 'selfhost');
const STAGE = process.env.STAGE_DIR || join(ROOT, 'selfhost', '.stage');

const DB_DIR = join(SELFHOST, 'database');
const WEB_DIR = process.env.WEB_BUILD || join(ROOT, 'kasirgo', 'build', 'web');
const ADMIN_DIR = process.env.ADMIN_BUILD || join(ROOT, 'kasirgo-admin', 'dist');
const INSTALLER = join(SELFHOST, 'installer');

function requireDir(dir, label) {
  if (!existsSync(dir)) {
    console.error(`✗ ${label} tidak ditemukan: ${dir}`);
    console.error('  Jalankan dump-database.sh dan build web/admin terlebih dulu.');
    process.exit(1);
  }
}

async function copyDir(src, dest) {
  await cp(src, dest, { recursive: true });
}

async function main() {
  requireDir(DB_DIR, 'Folder database');
  requireDir(join(WEB_DIR, 'index.html'), 'Build web');
  requireDir(WEB_DIR, 'Build web');
  requireDir(join(ADMIN_DIR, 'index.html'), 'Build admin');
  requireDir(ADMIN_DIR, 'Build admin');
  requireDir(INSTALLER, 'Installer');

  console.log('>> Menyiapkan staging...');
  await rm(STAGE, { recursive: true, force: true });
  await mkdir(STAGE, { recursive: true });

  await copyDir(DB_DIR, join(STAGE, 'database'));
  await copyDir(WEB_DIR, join(STAGE, 'app', 'web'));
  await copyDir(ADMIN_DIR, join(STAGE, 'app', 'admin'));
  // Installer: tanpa node_modules.
  await copyDir(INSTALLER, join(STAGE, 'installer'));
  const nm = join(STAGE, 'installer', 'node_modules');
  if (existsSync(nm)) await rm(nm, { recursive: true, force: true });

  const manifest = {
    name: 'KasirGo self-host backup package',
    type: 'duplicator-style',
    createdAt: new Date().toISOString(),
    files: {
      database: (await readdir(DB_DIR)).filter((f) => f.endsWith('.sql')),
      web: true,
      admin: true,
      installer: true,
    },
  };
  await writeFile(join(STAGE, 'MANIFEST.json'), JSON.stringify(manifest, null, 2));

  const stamp = new Date().toISOString().slice(0, 10);
  const out = join(ROOT, `kasirgo-selfhost-backup-${stamp}.zip`);
  const zip = spawnSync('zip', ['-r', '-q', out, '.'], { cwd: STAGE, stdio: 'inherit' });
  if (zip.status !== 0) {
    console.error('✗ Gagal membuat zip (butuh utilitas `zip`).');
    process.exit(1);
  }

  const s = await stat(out);
  console.log(`✓ Paket backup: ${out} (${(s.size / 1024).toFixed(1)} KB)`);
  console.log('  Unggah & ekstrak di server, lalu jalankan:');
  console.log('    cd kasirgo-selfhost/installer && npm install && npm start');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});