import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Config suara interaktif dari Control Plane
/// (platform_configs 'business_doctor' -> field 'audio').
class VoiceAudioConfig {
  final bool aktif;
  final bool teguran;
  final bool soundboxPos;

  const VoiceAudioConfig({
    this.aktif = true,
    this.teguran = true,
    this.soundboxPos = true,
  });

  static const fallback = VoiceAudioConfig();

  factory VoiceAudioConfig.fromMap(Map<String, dynamic> m) {
    bool b(dynamic v, bool d) {
      if (v == null) return d;
      if (v is bool) return v;
      final s = v.toString().toLowerCase();
      return s == 'true' || s == '1' || s == 'ya';
    }

    return VoiceAudioConfig(
      aktif: b(m['aktif'], true),
      teguran: b(m['teguran'], true),
      soundboxPos: b(m['soundbox_pos'], true),
    );
  }

  Map<String, dynamic> toMap() => {
        'aktif': aktif,
        'teguran': teguran,
        'soundbox_pos': soundboxPos,
      };
}

/// Layanan suara interaktif KasirGo 3.0.
///
/// - Soundbox POS: bacakan nominal pembayaran saat transaksi sukses.
/// - Teguran Dokter Bisnis: bacakan teguran eskalasi agar owner gaptek
///   langsung mendengar (bukan hanya membaca).
///
/// Semua fitur di-gate oleh config Control Plane (`audio`). Bila TTS tidak
/// tersedia di perangkat/browser, seluruh pemanggilan aman (no-op).
class VoiceService {
  VoiceService._internal();
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;

  static const _cacheKey = 'kasirgo_voice_audio_cfg';
  static const _cacheTsKey = 'kasirgo_voice_audio_cfg_ts';
  static const _cacheTtlSeconds = 3600;

  final FlutterTts _tts = FlutterTts();
  VoiceAudioConfig _config = VoiceAudioConfig.fallback;
  bool _ready = false;
  bool _available = true;

  VoiceAudioConfig get config => _config;
  bool get available => _available && _config.aktif;

  SupabaseClient get _client => Supabase.instance.client;

  /// Siapkan mesin TTS + muat config (cache 1 jam, fallback default).
  Future<void> init({bool forceRefresh = false}) async {
    await loadConfig(forceRefresh: forceRefresh);
    if (_ready) return;
    try {
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(false);
      _ready = true;
    } catch (e) {
      _available = false;
      debugPrint('VoiceService.init TTS error: $e');
    }
  }

  Future<VoiceAudioConfig> loadConfig({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_cacheTsKey) ?? 0;
    final fresh =
        DateTime.now().millisecondsSinceEpoch - ts < _cacheTtlSeconds * 1000;

    if (!forceRefresh && fresh) {
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        try {
          _config = VoiceAudioConfig.fromMap(
              Map<String, dynamic>.from(_decode(cached) as Map));
          return _config;
        } catch (_) {}
      }
    }

    try {
      final res = await _client
          .from('platform_configs')
          .select('value')
          .eq('key', 'business_doctor')
          .eq('scope', 'global')
          .order('version', ascending: false)
          .limit(1)
          .maybeSingle();
      final value = res?['value'];
      if (value is Map && value['audio'] is Map) {
        _config = VoiceAudioConfig.fromMap(
            Map<String, dynamic>.from(value['audio'] as Map));
        await prefs.setString(_cacheKey, _encode(_config.toMap()));
        await prefs.setInt(_cacheTsKey, DateTime.now().millisecondsSinceEpoch);
        return _config;
      }
    } catch (e) {
      debugPrint('VoiceService.loadConfig error: $e');
    }

    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        _config = VoiceAudioConfig.fromMap(
            Map<String, dynamic>.from(_decode(cached) as Map));
        return _config;
      } catch (_) {}
    }
    _config = VoiceAudioConfig.fallback;
    return _config;
  }

  /// Soundbox POS: bacakan nominal pembayaran yang diterima.
  Future<void> announcePayment({
    required double amount,
    String? method,
    double change = 0,
    String? customerName,
  }) async {
    if (!available || !_config.soundboxPos) return;
    await init();
    if (!available) return;

    final buf = StringBuffer('Pembayaran diterima ');
    if (method != null && method.trim().isNotEmpty) {
      buf.write('${_methodLabel(method)} ');
    }
    buf.write(_rupiah(amount));
    buf.write('. ');
    if (change > 0) {
      buf.write('Kembalian ${_rupiah(change)}. ');
    }
    if (customerName != null && customerName.trim().isNotEmpty) {
      buf.write('Terima kasih ${customerName.trim()}.');
    } else {
      buf.write('Terima kasih.');
    }
    await speak(buf.toString());
  }

  /// Teguran Dokter Bisnis: bacakan agar terdengar langsung oleh owner.
  Future<void> announceReprimand(String text) async {
    if (!available || !_config.teguran) return;
    final clean = text.trim();
    if (clean.isEmpty) return;
    await init();
    if (!available) return;
    await speak(clean);
  }

  /// Ucapkan teks bebas (dipakai briefing/ucapan lain).
  Future<void> speak(String text) async {
    if (!available) return;
    final clean = text.trim();
    if (clean.isEmpty) return;
    await init();
    if (!available) return;
    try {
      await _tts.stop();
      await _tts.speak(clean);
    } catch (e) {
      debugPrint('VoiceService.speak error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  String _methodLabel(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
      case 'tunai':
        return 'tunai';
      case 'qris':
        return 'QRIS';
      case 'transfer':
        return 'transfer';
      default:
        return method;
    }
  }

  String _rupiah(double amount) {
    // Angka polos tanpa pemisah ribuan agar mesin TTS membaca nominal
    // dengan benar (mis. 12000 -> "dua belas ribu", bukan "dua belas titik").
    return 'rupiah ${amount.round()}';
  }

  dynamic _decode(String s) => jsonDecode(s);

  String _encode(Map<String, dynamic> m) => jsonEncode(m);
}
