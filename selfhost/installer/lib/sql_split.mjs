// Split sebuah file SQL (bisa berisi DDL, fungsi dollar-quoted, INSERT multi-baris,
// COPY, dll.) menjadi daftar pernyataan. Menangani: komentar baris `--`, komentar
// blok `/* */`, string '...' dengan escape, identifier "..." dan $$...$$ dollar quote.
export function splitSqlStatements(sql) {
  const statements = [];
  let cur = '';
  let i = 0;
  const n = sql.length;
  let inSingle = false;
  let inDouble = false;
  let dollarTag = '';
  let inLineComment = false;
  let inBlockComment = false;

  while (i < n) {
    const c = sql[i];
    const next = sql[i + 1];

    if (inLineComment) {
      cur += c;
      if (c === '\n') inLineComment = false;
      i++;
      continue;
    }
    if (inBlockComment) {
      cur += c;
      if (c === '*' && next === '/') {
        cur += next;
        i += 2;
        inBlockComment = false;
        continue;
      }
      i++;
      continue;
    }
    if (inSingle) {
      cur += c;
      if (c === "'" && next === "'") { cur += next; i += 2; continue; }
      if (c === "'") inSingle = false;
      i++;
      continue;
    }
    if (inDouble) {
      cur += c;
      if (c === '"' && next === '"') { cur += next; i += 2; continue; }
      if (c === '"') inDouble = false;
      i++;
      continue;
    }
    if (dollarTag) {
      if (c === '$' && sql.startsWith(dollarTag, i)) {
        cur += dollarTag;
        i += dollarTag.length;
        dollarTag = '';
        continue;
      }
      cur += c;
      i++;
      continue;
    }

    // Di luar string/komentar
    if (c === '-' && next === '-') { inLineComment = true; cur += c; i++; continue; }
    if (c === '/' && next === '*') { inBlockComment = true; cur += c; i++; continue; }
    if (c === "'") { inSingle = true; cur += c; i++; continue; }
    if (c === '"') { inDouble = true; cur += c; i++; continue; }
    if (c === '$') {
      const m = /^\$(?:[A-Za-z_][A-Za-z0-9_]*)?\$/.exec(sql.slice(i));
      if (m) { dollarTag = m[0]; cur += dollarTag; i += dollarTag.length; continue; }
    }
    if (c === ';') {
      const s = cur.trim();
      if (s) statements.push(s);
      cur = '';
      i++;
      continue;
    }
    cur += c;
    i++;
  }

  const s = cur.trim();
  if (s) statements.push(s);
  return statements;
}

export function isStandaloneControl(sql) {
  const t = sql.trim().toUpperCase();
  return (
    t === 'BEGIN' ||
    t === 'COMMIT' ||
    t === 'ROLLBACK' ||
    t.startsWith('SET SESSION') ||
    t.startsWith('SET statement_timeout') ||
    t.startsWith('SELECT pg_catalog.set_config')
  );
}