// lib/utils/error_messages.dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mengubah error teknis (exception / kode sistem) menjadi pesan bahasa
/// manusia yang ramah untuk ditampilkan ke pengguna akhir.
///
/// Pesan yang sudah dibuat manual (mis. `throw Exception('Minimal harus ada 1
/// outlet')`) dikembalikan apa adanya; hanya error teknis yang diterjemahkan.
String friendlyError(
  Object error, {
  String fallback = 'Terjadi kesalahan. Silakan coba lagi.',
}) {
  final raw = _rawMessage(error);
  final lower = raw.toLowerCase();

  // --- Autentikasi ---
  if (lower.contains('email_not_confirmed') ||
      lower.contains('email not confirmed')) {
    return 'Email belum dikonfirmasi. Silakan cek email Anda (kotak masuk / folder spam) lalu klik tautan konfirmasi.';
  }
  if (lower.contains('invalid login credentials') ||
      lower.contains('invalid_credentials')) {
    return 'Email atau kata sandi salah. Silakan periksa kembali.';
  }
  if (lower.contains('user_already_exists') ||
      lower.contains('already registered') ||
      lower.contains('already been registered') ||
      lower.contains('sudah terdaftar')) {
    return 'Email sudah terdaftar. Silakan masuk atau gunakan email lain.';
  }
  if (lower.contains('weak_password') || lower.contains('password should be')) {
    return 'Kata sandi terlalu lemah. Gunakan minimal 6 karakter.';
  }
  if (lower.contains('over_email_send_rate_limit') ||
      lower.contains('rate limit') ||
      lower.contains('too many requests') ||
      lower.contains('429')) {
    return 'Terlalu banyak percobaan. Mohon tunggu sebentar lalu coba lagi.';
  }
  if (lower.contains('signup_disabled') ||
      lower.contains('signups not allowed')) {
    return 'Pendaftaran akun sedang dinonaktifkan. Silakan hubungi admin.';
  }
  if (lower.contains('email address not authorized') ||
      lower.contains('not authorized')) {
    return 'Email ini belum diizinkan. Silakan hubungi admin.';
  }

  // --- Jaringan ---
  if (lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('connection closed') ||
      lower.contains('network is unreachable') ||
      lower.contains('failed to fetch') ||
      lower.contains('xmlhttprequest')) {
    return 'Tidak ada koneksi internet. Periksa jaringan Anda lalu coba lagi.';
  }
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return 'Koneksi terlalu lama. Silakan coba lagi.';
  }

  // --- Database / server ---
  if (lower.contains('pgrst') || lower.contains('postgrest')) {
    return 'Data tidak dapat dimuat saat ini. Silakan coba lagi.';
  }
  if (lower.contains('functionexception') || lower.contains('edge function')) {
    return 'Layanan sedang tidak tersedia. Silakan coba lagi nanti.';
  }
  if (lower.contains('row-level security') ||
      lower.contains('permission denied') ||
      lower.contains('insufficient privilege')) {
    return 'Anda tidak memiliki akses untuk tindakan ini.';
  }
  if (lower.contains('duplicate key') || lower.contains('unique constraint')) {
    return 'Data sudah ada. Silakan gunakan nilai lain.';
  }

  // Pesan manual yang sudah ramah: kembalikan apa adanya.
  if (raw.isNotEmpty && !_looksTechnical(raw)) return raw;

  return fallback;
}

/// Kode error teknis dari Supabase (bila ada), mis. `email_not_confirmed`.
String? errorCode(Object error) {
  if (error is AuthException) return error.code;
  if (error is PostgrestException) return error.code;
  return null;
}

/// True bila kegagalan login karena email pendaftaran belum dikonfirmasi.
bool isEmailNotConfirmed(Object error) {
  if (errorCode(error) == 'email_not_confirmed') return true;
  return _rawMessage(error).toLowerCase().contains('email not confirmed');
}

String _rawMessage(Object error) {
  if (error is AuthException) return error.message;
  if (error is PostgrestException) return error.message;
  if (error is FunctionException) {
    final d = error.details;
    if (d is Map && d['error'] != null) return d['error'].toString();
    if (d != null) return d.toString();
    return error.toString();
  }
  var s = error.toString();
  s = s.replaceFirst('Exception: ', '');
  return s.trim();
}

/// Menandai apakah teks masih berupa pesan teknis (stack/kode/objek) yang
/// sebaiknya tidak ditampilkan mentah ke pengguna.
bool _looksTechnical(String s) {
  final t = s.toLowerCase();
  return t.contains('exception') ||
      t.contains('error:') ||
      t.contains('code:') ||
      t.contains('pgrst') ||
      t.contains('statuscode') ||
      t.contains('stack') ||
      t.contains('{') ||
      t.contains('}') ||
      RegExp(r'\b\d{3}\b').hasMatch(t) ||
      t.length > 160;
}
