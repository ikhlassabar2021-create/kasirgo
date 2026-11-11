#!/usr/bin/env node
// Restore database + tulis state.json dalam SATU perintah (restore sekali-klik).
//
// Penggunaan:
//   node restore-cli.mjs "postgresql://user:password@host:5432/dbname" \
//     --url  "https://<project>.supabase.co" \
//     --anon "<publishable anon key>"
//
// Atau pakai environment variable:
//   DATABASE_URL="postgresql://..." SUPABASE_URL="..." SUPABASE_ANON_KEY="..." \
//     node restore-cli.mjs
//
// Setelah selesai, jalankan `npm start`. Server akan langsung menyajikan app & admin
// tanpa wizard lagi (karena state.json sudah ditulis).
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { writeFile } from 'node:fs/promises';
import { testConnection, restoreDatabase } from './lib/restore.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const BASE = resolve(__dirname, '..');
const DB_DIR = join(BASE, 'database');
const STATE_FILE = join(BASE, 'state.json');

function parseConn(str) {
  const url = new URL(str.includes('://') ? str : `postgresql://${str}`);
  if (!['postgresql:', 'postgres:'].includes(url.protocol)) {
    throw new Error('Koneksi harus diawali postgresql:// atau postgres://');
  }
  if (!url.hostname || !url.username) {
    throw new Error('Koneksi tidak lengkap: butuh user, host, database (dan password).');
  }
  return {
    host: decodeURIComponent(url.hostname),
    port: url.port || '5432',
    database: decodeURIComponent(url.pathname.replace(/^\/+/, '')) || 'postgres',
    user: decodeURIComponent(url.username),
    password: decodeURIComponent(url.password || ''),
  };
}

function arg(name, fallback = '') {
  const i = process.argv.indexOf(name);
  return i !== -1 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}

async function main() {
  const urlArg = process.argv[2] || process.env.DATABASE_URL;
  const supabaseUrl = arg('--url', process.env.SUPABASE_URL || '');
  const supabaseAnonKey = arg('--anon', process.env.SUPABASE_ANON_KEY || '');

  if (!urlArg) {
    console.error(
      'Pakai: node restore-cli.mjs "<postgresql://...>" --url <supabaseUrl> --anon <anonKey>',
    );
    console.error('      atau set env DATABASE_URL.');
    process.exit(1);
  }

  const conn = parseConn(urlArg);
  const masked = `${conn.user}@${conn.host}:${conn.port}/${conn.database}`;
  console.log(`>> Tes koneksi: ${masked}`);

  let t;
  try {
    t = await testConnection(conn);
  } catch (e) {
    console.error(`✗ Koneksi gagal: ${e && e.message ? e.message : e}`);
    process.exit(1);
  }
  console.log(`✓ Terhubung: ${t.version || 'ok'}`);

  console.log('>> Restore database...');
  let total = 0;
  const log = [];
  await restoreDatabase(conn, DB_DIR, (e) => {
    if (e.error) {
      console.error(`   ✗ ${e.file}: ${e.error}`);
      log.push(`${e.file}: ERROR ${e.error}`);
    } else if (e.ok !== undefined) {
      console.log(`   ✓ ${e.file}: ${e.ok} ok, ${e.failed} gagal`);
      total += e.ok;
      log.push(`${e.file}: ${e.ok} ok, ${e.failed} gagal`);
    }
  });

  await writeFile(
    STATE_FILE,
    JSON.stringify(
      {
        restored: true,
        host: conn.host,
        port: conn.port,
        database: conn.database,
        user: conn.user,
        password: conn.password,
        supabaseUrl,
        supabaseAnonKey,
        restoredAt: new Date().toISOString(),
      },
      null,
      2,
    ),
  );

  console.log(`\n✓ Restore selesai: ${total} statement berhasil.`);
  if (supabaseUrl) console.log(`✓ Konfigurasi app: ${supabaseUrl}`);
  console.log('\nJalankan server (sajikan app + admin tanpa wizard):');
  console.log('  npm start');
}

main().catch((e) => {
  console.error(`✗ ${e && e.message ? e.message : e}`);
  process.exit(1);
});