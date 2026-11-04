import { readFile, readdir } from 'node:fs/promises';
import { join, extname } from 'node:path';
import pg from 'pg';
import { splitSqlStatements, isStandaloneControl } from './sql_split.mjs';

const { Client } = pg;

function sslFor(host) {
  // Supabase pooler/cloud butuh SSL; local/self-host biasanya tidak.
  const needs = host?.includes('supabase') || host?.includes('pooler');
  return needs ? { rejectUnauthorized: false } : false;
}

export async function testConnection(conn) {
  const client = new Client({
    host: conn.host,
    port: Number(conn.port) || 5432,
    database: conn.database,
    user: conn.user,
    password: conn.password,
    ssl: sslFor(conn.host),
    connectionTimeoutMillis: 8000,
  });
  try {
    await client.connect();
    const r = await client.query('SELECT version()');
    return { ok: true, version: r.rows[0]?.version ?? '' };
  } finally {
    await client.end().catch(() => {});
  }
}

export async function restoreDatabase(conn, dir, onProgress = () => {}) {
  const files = (await readdir(dir))
    .filter((f) => extname(f).toLowerCase() === '.sql')
    .sort();

  if (!files.length) {
    throw new Error('Tidak ada file *.sql di folder database.');
  }

  const client = new Client({
    host: conn.host,
    port: Number(conn.port) || 5432,
    database: conn.database,
    user: conn.user,
    password: conn.password,
    ssl: sslFor(conn.host),
  });
  await client.connect();

  let total = 0;
  const perFile = [];
  try {
    for (const file of files) {
      const raw = await readFile(join(dir, file), 'utf8');
      const statements = splitSqlStatements(raw).filter((s) => !isStandaloneControl(s));
      let ok = 0;
      let failed = 0;
      for (const stmt of statements) {
        try {
          await client.query(stmt);
          ok++;
          total++;
        } catch (e) {
          failed++;
          onProgress({ file, error: String(e && e.message ? e.message : e) });
        }
      }
      perFile.push({ file, ok, failed });
      onProgress({ file, ok, failed });
    }
  } finally {
    await client.end().catch(() => {});
  }

  return { total, files: perFile };
}