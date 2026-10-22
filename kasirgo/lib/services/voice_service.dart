import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/terbilang.dart';

/// Config suara interaktif dari Control Plane
/// (platform_configs 'business_doctor' -> field 'audio').
class VoiceAudioConfig {
  /// Master switch. Bila false, SEMUA suara dimatikan.
  final bool aktif;
  final bool sapaanAwal;
  final bool fullVoiceLoop;
  final bool apelPagi;
  final bool teguranResep;
  final bool soundboxPos;
  final bool shopFloor;

  /// Bila false, master switch per outlet diabaikan (diatur admin global).
  final bool perOutlet;

  const VoiceAudioConfig({
    this.aktif = true,
    this.sapaanAwal = true,
    this.fullVoiceLoop = true,
    this.apelPagi = true,
    this.teguranResep = true,
    this.soundboxPos = true,
    this.shopFloor = true,
    this.perOutlet = true,
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
      sapaanAwal: b(m['sapaan_awal'], true),
      fullVoiceLoop: b(m['full_voice_loop'], true),
      apelPagi: b(m['apel_pagi'], true),
      teguranResep: b(m['teguran_resep'] ?? m['teguran'], true),
      soundboxPos: b(m['soundbox_pos'], true),
      shopFloor: b(m['shop_floor'], true),
      perOutlet: b(m['per_outlet'], true),
    );
  }

  Map<String, dynamic> toMap() => {
        'aktif': aktif,
        'sapaan_awal': sapaanAwal,
        'full_voice_loop': fullVoiceLoop,
        'apel_pagi': apelPagi,
        'teguran_resep': teguranResep,
        'soundbox_pos': soundboxPos,
        'shop_floor': shopFloor,
        'per_outlet': perOutlet,
      };

  /// Gabungkan preferensi per outlet (master switch owner) di atas config
  /// global Control Plane. Field yang tidak diisi tetap ikut global.
  VoiceAudioConfig overrideWith(Map<String, dynamic>? prefs) {
    if (prefs == null || prefs.isEmpty) return this;
    bool? b(dynamic v) {
      if (v == null) return null;
      if (v is bool) return v;
      final s = v.toString().toLowerCase();
      if (s == 'true' || s == '1' || s == 'ya') return true;
      if (s == 'false' || s == '0' || s == 'tidak') return false;
      return null;
    }

    return VoiceAudioConfig(
      aktif: b(prefs['aktif']) ?? aktif,
      sapaanAwal: b(prefs['sapaan_awal']) ?? sapaanAwal,
      fullVoiceLoop: b(prefs['full_voice_loop']) ?? fullVoiceLoop,
      apelPagi: b(prefs['apel_pagi']) ?? apelPagi,
      teguranResep:
          b(prefs['teguran_resep'] ?? prefs['teguran']) ?? teguranResep,
      soundboxPos: b(prefs['soundbox_pos']) ?? soundboxPos,
      shopFloor: b(prefs['shop_floor']) ?? shopFloor,
      perOutlet: perOutlet,
    );
  }
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
  VoiceAudioConfig _global = VoiceAudioConfig.fallback;
  VoiceAudioConfig _config = VoiceAudioConfig.fallback;
  Map<String, dynamic> _outletPrefs = const {};
  String? _outletId;
  bool _ready = false;
  bool _available = true;

  VoiceAudioConfig get config => _config;
  bool get available => _available && _config.aktif;
  String? get outletId => _outletId;

  SupabaseClient get _client => Supabase.instance.client;

  /// Siapkan mesin TTS + muat config (cache 1 jam, fallback default).
  Future<void> init({bool forceRefresh = false, String? outletId}) async {
    await loadConfig(forceRefresh: forceRefresh);
    if (outletId != null && outletId.isNotEmpty) {
      await applyOutletPrefs(outletId);
    }
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
          _global = VoiceAudioConfig.fromMap(
              Map<String, dynamic>.from(_decode(cached) as Map));
          _config = _global.overrideWith(_outletPrefs);
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
        _global = VoiceAudioConfig.fromMap(
            Map<String, dynamic>.from(value['audio'] as Map));
        _config = _global.overrideWith(_outletPrefs);
        await prefs.setString(_cacheKey, _encode(_global.toMap()));
        await prefs.setInt(_cacheTsKey, DateTime.now().millisecondsSinceEpoch);
        return _config;
      }
    } catch (e) {
      debugPrint('VoiceService.loadConfig error: $e');
    }

    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        _global = VoiceAudioConfig.fromMap(
            Map<String, dynamic>.from(_decode(cached) as Map));
        _config = _global.overrideWith(_outletPrefs);
        return _config;
      } catch (_) {}
    }
    _global = VoiceAudioConfig.fallback;
    _config = _global.overrideWith(_outletPrefs);
    return _config;
  }

  /// Muat master switch suara milik outlet (kolom
  /// `doctor_outlet_profile.audio_prefs`). Cache lokal 1 jam.
  Future<VoiceAudioConfig> applyOutletPrefs(
    String outletId, {
    bool forceRefresh = false,
  }) async {
    if (outletId.trim().isEmpty) return _config;
    if (!_global.perOutlet) {
      _outletId = outletId;
      _outletPrefs = const <String, dynamic>{};
      _config = _global;
      return _config;
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'kasirgo_voice_outlet_prefs_$outletId';
    final tsKey = '${key}_ts';
    final ts = prefs.getInt(tsKey) ?? 0;
    final fresh =
        DateTime.now().millisecondsSinceEpoch - ts < _cacheTtlSeconds * 1000;

    if (!forceRefresh && fresh && _outletId == outletId) return _config;

    if (!forceRefresh && fresh) {
      final cached = prefs.getString(key);
      if (cached != null) {
        try {
          _outletPrefs = Map<String, dynamic>.from(_decode(cached) as Map);
          _outletId = outletId;
          _config = _global.overrideWith(_outletPrefs);
          return _config;
        } catch (_) {}
      }
    }

    try {
      final res = await _client
          .from('doctor_outlet_profile')
          .select('audio_prefs')
          .eq('outlet_id', outletId)
          .maybeSingle();
      final raw = res?['audio_prefs'];
      _outletPrefs = raw is Map
          ? Map<String, dynamic>.from(raw)
          : const <String, dynamic>{};
      _outletId = outletId;
      _config = _global.overrideWith(_outletPrefs);
      await prefs.setString(key, _encode(_outletPrefs));
      await prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
      return _config;
    } catch (e) {
      debugPrint('VoiceService.applyOutletPrefs error: $e');
    }
    return _config;
  }

  /// Simpan master switch suara outlet (dipanggil setelah DB tersimpan).
  Future<void> setOutletPrefs(
    String outletId,
    Map<String, dynamic> prefs,
  ) async {
    if (outletId.trim().isEmpty) return;
    _outletId = outletId;
    _outletPrefs = Map<String, dynamic>.from(prefs);
    _config = _global.overrideWith(_outletPrefs);
    final sp = await SharedPreferences.getInstance();
    final key = 'kasirgo_voice_outlet_prefs_$outletId';
    await sp.setString(key, _encode(_outletPrefs));
    await sp.setInt('${key}_ts', DateTime.now().millisecondsSinceEpoch);
  }

  /// Soundbox POS: bacakan nominal pembayaran yang diterima.
  Future<void> announcePayment({
    required double amount,
    String? method,
    double change = 0,
    String? customerName,
    String? outletId,
  }) async {
    if (outletId != null && outletId.isNotEmpty) {
      await applyOutletPrefs(outletId);
    }
    if (!available || !_config.soundboxPos) return;
    await init();
    if (!available) return;

    final buf = StringBuffer('Konfirmasi diterima. Masuk, ');
    buf.write(_terbilangRupiah(amount));
    if (method != null && method.trim().isNotEmpty) {
      buf.write(' ${_methodLabel(method)}');
    }
    buf.write('. ');
    if (change > 0) {
      buf.write('Kembalian ${_terbilangRupiah(change)}. ');
    }
    if (customerName != null && customerName.trim().isNotEmpty) {
      buf.write('Terima kasih ${customerName.trim()}.');
    } else {
      buf.write('Terima kasih.');
    }
    await speak(buf.toString());
  }

  /// Sapaan awal + apel pagi saat aplikasi dibuka (maksimal 1x per hari).
  Future<void> greetOnOpen({String? outletId, String? ownerName}) async {
    if (outletId != null && outletId.isNotEmpty) {
      await applyOutletPrefs(outletId);
    }
    if (!available || (!_config.sapaanAwal && !_config.apelPagi)) return;
    await init();
    if (!available) return;
    final now = DateTime.now();
    final buf = StringBuffer();
    if (_config.sapaanAwal) {
      final who = ownerName?.trim() ?? '';
      buf.write(who.isEmpty
          ? 'Selamat datang kembali, Bos.'
          : 'Selamat datang kembali, $who.');
    }
    if (_config.apelPagi && now.hour < 11) {
      if (buf.isNotEmpty) buf.write(' ');
      buf.write('Apel pagi: cek stok, siapkan modal, lalu mulai jualan.');
    }
    if (buf.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    final key = 'kasirgo_voice_greet_${_outletId ?? 'global'}_'
        '${now.year}${now.month}${now.day}';
    if (sp.getBool(key) == true) return;
    await sp.setBool(key, true);
    await speak(buf.toString());
  }

  /// Pengingat shop floor saat kasir mulai berjualan (1x per hari).
  Future<void> announceShopFloorReminder({String? outletId}) async {
    if (outletId != null && outletId.isNotEmpty) {
      await applyOutletPrefs(outletId);
    }
    if (!available || !_config.shopFloor) return;
    await init();
    if (!available) return;
    final now = DateTime.now();
    final sp = await SharedPreferences.getInstance();
    final key = 'kasirgo_voice_shopfloor_${_outletId ?? 'global'}_'
        '${now.year}${now.month}${now.day}';
    if (sp.getBool(key) == true) return;
    await sp.setBool(key, true);
    await speak(
      'Pengingat toko: rapikan display, cek harga, dan sapa setiap pelanggan.',
    );
  }

  /// Teguran Dokter Bisnis: bacakan agar terdengar langsung oleh owner.
  Future<void> announceReprimand(String text, {String? outletId}) async {
    if (outletId != null && outletId.isNotEmpty) {
      await applyOutletPrefs(outletId);
    }
    if (!available || !_config.teguranResep) return;
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

  /// Nominal dalam kata agar TTS membacanya jelas:
  /// 25000 -> "dua puluh lima ribu rupiah".
  String _terbilangRupiah(double amount) =>
      '${Terbilang.convert(amount)} rupiah';

  dynamic _decode(String s) => jsonDecode(s);

  String _encode(Map<String, dynamic> m) => jsonEncode(m);
}
