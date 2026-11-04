// KasirGo — konfigurasi runtime frontend (self-host / cPanel shared).
// Dibaca aplikasi web (window.KASIRGO_CONFIG) dan admin
// (window.__KASIRGO_ADMIN_CONFIG__) SEBELUM bundle dimuat, sehingga
// frontend bisa menunjuk ke Supabase project lain TANPA rebuild.
//
// Nilai di bawah = bawaan (Supabase cloud produksi). Untuk menunjuk ke
// project Supabase yang berbeda (mis. hasil restore), ganti URL dan anon
// key-nya, lalu simpan. Aplikasi Android/APK tetap memakai nilai bawaan.
window.KASIRGO_CONFIG = {
  supabaseUrl: 'https://lmvjecdvfzsmrowwwpck.supabase.co',
  supabaseAnonKey: 'sb_publishable_8RJnG66i_37cih8GTG1sBA_0B91KOW_',
};
window.__KASIRGO_ADMIN_CONFIG__ = window.KASIRGO_CONFIG;