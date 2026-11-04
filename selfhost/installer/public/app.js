(function () {
  const steps = Array.from(document.querySelectorAll('.step'));
  let current = 0;

  const byName = (state) => {
    const out = {};
    for (const el of state.querySelectorAll('[name]')) out[el.name] = el.value.trim();
    return out;
  };
  const status = (el, msg, ok) => {
    el.textContent = msg || '';
    el.className = 'status ' + (ok === undefined ? '' : ok ? 'ok' : 'err');
  };

  function show(i) {
    steps.forEach((s, idx) => s.classList.toggle('hidden', idx !== i));
    current = i;
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  document.addEventListener('click', (e) => {
    const next = e.target.closest('[data-next]');
    if (next) { show(Math.min(current + 1, steps.length - 1)); return; }
    const prev = e.target.closest('[data-prev]');
    if (prev) { show(Math.max(current - 1, 0)); return; }

    if (e.target.closest('#test-db')) {
      const step = steps[1];
      const st = status(step.querySelector('#db-status'), 'Menghubungi database...');
      fetch('/api/test-db', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(byName(step)),
      })
        .then((r) => r.json())
        .then((r) => status(step.querySelector('#db-status'), r.ok ? 'Koneksi berhasil: ' + (r.version || 'OK') : 'Gagal: ' + (r.error || ''), r.ok))
        .catch((err) => status(step.querySelector('#db-status'), 'Gagal: ' + err, false));
      return;
    }

    if (e.target.closest('#run-restore')) {
      const db = byName(steps[1]);
      const api = byName(steps[2]);
      const btn = document.querySelector('#run-restore');
      const log = document.querySelector('#log');
      btn.disabled = true;
      btn.textContent = 'Memulihkan...';
      log.textContent = 'Memulai restore...';
      fetch('/api/restore', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...db, ...api }),
      })
        .then((r) => r.json())
        .then((res) => {
          if (res.ok) {
            log.textContent = 'Selesai. Total pernyataan: ' + res.total + '\n' + (res.log || []).join('\n');
            setTimeout(() => show(4), 600);
          } else {
            log.textContent = 'Gagal: ' + (res.error || 'unknown');
            btn.disabled = false;
            btn.textContent = 'Jalankan Restore';
          }
        })
        .catch((err) => {
          log.textContent = 'Gagal: ' + err;
          btn.disabled = false;
          btn.textContent = 'Jalankan Restore';
        });
      return;
    }
  });

  // Bila sudah pernah di-restore, langsung arahkan ke aplikasi.
  fetch('/api/state')
    .then((r) => r.json())
    .then((s) => {
      if (s.restored) {
        const h = document.querySelector('#open-app');
        if (h) h.href = '/';
        window.location.replace('/');
      } else {
        // Prefill Supabase URL dari domain saat ini.
        const urlInput = document.querySelector('[name="supabaseUrl"]');
        if (urlInput && !urlInput.value) urlInput.value = window.location.origin;
      }
    })
    .catch(() => {});
})();