import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
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

/// Profil intonasi per persona Dokter Bisnis.
///
/// Persona TIDAK boleh sekadar mengganti teks: warna suara (tinggi nada,
/// tempo, volume) harus berbeda agar owner langsung mendengar bedanya.
class VoicePersonaProfile {
  final double rate;
  final double pitch;
  final double volume;
  final String sample;

  /// Kecepatan putar audio cloud (1.0 = normal). Google TTS hanya punya satu
  /// warna suara, jadi tempo inilah yang membedakan antar persona.
  final double cloudRate;

  /// Preferensi jenis suara perangkat: 'male' / 'female' / null (bebas).
  final String? gender;

  const VoicePersonaProfile({
    required this.rate,
    required this.pitch,
    required this.volume,
    required this.sample,
    this.cloudRate = 1.0,
    this.gender,
  });
}

/// Satu suara TTS yang tersedia di perangkat/browser.
/// Satu potongan audio dari Edge Function `tts_speak`.
///
/// [pauseMs] adalah jeda yang dipasang klien setelah potongan ini selesai,
/// meniru jeda napas antar kalimat pada pembicara manusia.
class _SpeechSegment {
  final Uint8List bytes;
  final int pauseMs;
  const _SpeechSegment(this.bytes, this.pauseMs);
}

class VoiceOption {
  final String name;
  final String locale;
  final bool network;

  const VoiceOption({
    required this.name,
    required this.locale,
    this.network = false,
  });

  /// Label ramah untuk owner gaptek, mis. "Suara Wanita (id-ID, online)".
  String get label {
    final n = name.toLowerCase();
    String gender = '';
    if (n.contains('female') || n.contains('wanita')) {
      gender = 'Wanita';
    } else if (n.contains('male') || n.contains('pria')) {
      gender = 'Pria';
    }
    final parts = <String>[
      if (gender.isNotEmpty) gender else 'Suara Indonesia',
      locale.isEmpty ? 'id-ID' : locale,
      if (network) 'online',
    ];
    return parts.join(' - ');
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
  static const _personaKey = 'kasirgo_voice_persona';
  static const _voiceKey = 'kasirgo_voice_device';

  /// Rate/pitch/volume dijaga di rentang aman Android & Web Speech API
  /// (pitch 0.5-2.0, rate 0.1-10).
  static const Map<String, VoicePersonaProfile> personaProfiles = {
    'bos_tegas': VoicePersonaProfile(
      rate: 0.47,
      pitch: 0.80,
      volume: 1.0,
      cloudRate: 0.93,
      gender: 'male',
      sample: 'Bos, saya lihat langsung datanya. Hari ini kita bereskan '
          'yang paling penting dulu.',
    ),
    'partner_santai': VoicePersonaProfile(
      rate: 0.54,
      pitch: 1.16,
      volume: 0.95,
      cloudRate: 1.06,
      gender: 'female',
      sample: 'Santai aja, Bos. Saya temani pelan-pelan. Kita mulai dari '
          'yang paling gampang dulu, ya.',
    ),
    'analis_taktis': VoicePersonaProfile(
      rate: 0.50,
      pitch: 0.94,
      volume: 0.92,
      cloudRate: 0.98,
      gender: 'male',
      sample: 'Berdasarkan data tujuh hari terakhir, ada tiga hal yang perlu '
          'kita perhatikan. Mari kita bahas satu per satu.',
    ),
  };

  static const _defaultPersona = 'bos_tegas';

  final FlutterTts _tts = FlutterTts();
  AudioPlayer _player = AudioPlayer();

  /// Suara cloud (Edge Function `tts_speak` -> Google TTS). Jauh lebih luwes
  /// daripada TTS bawaan HP/browser. Dimatikan sementara setelah 3 kegagalan
  /// beruntun agar tidak memperlambat setiap kalimat.
  bool _cloudOn = true;
  int _cloudFail = 0;
  VoiceAudioConfig _global = VoiceAudioConfig.fallback;
  VoiceAudioConfig _config = VoiceAudioConfig.fallback;
  Map<String, dynamic> _outletPrefs = const {};
  String? _outletId;
  bool _ready = false;
  bool _available = true;
  Completer<void>? _speakDone;

  /// Nomor generasi pemutaran. Dinaikkan setiap `stop()`/pemutaran baru agar
  /// loop segmen lama berhenti sendiri tanpa memotong suara yang baru.
  int _speakGen = 0;

  /// Generasi antrean ucapan. Dinaikkan di [stop] agar ucapan yang masih
  /// mengantre setelah stop langsung dibuang, bukan dibacakan telat.
  int _speakEpoch = 0;

  /// Antrean serial semua ucapan: setiap pemanggilan [speak] menunggu giliran
  /// sehingga pengumuman (pembayaran, teguran) tidak pernah memotong jawaban
  /// Dokter yang sedang dibaca sampai habis.
  Future<void> _speakChain = Future<void>.value();
  String _persona = _defaultPersona;
  String? _voiceName;
  String? _voiceLocale;
  List<VoiceOption> _voices = const [];

  VoiceAudioConfig get config => _config;

  /// Suara tersedia bila TTS perangkat siap ATAU suara cloud masih aktif.
  bool get available => (_available || _cloudOn) && _config.aktif;

  /// True bila audio sedang diambil dari cloud (suara neural).
  bool get cloudActive => _cloudOn;
  String? get outletId => _outletId;
  String get persona => _persona;

  /// Nama voice TTS yang sedang dipakai (null = voice default perangkat).
  String? get voiceName => _voiceName;

  /// Locale voice TTS yang sedang dipakai (mis. `id-ID`).
  String? get voiceLocale => _voiceLocale;
  String get personaSample =>
      (personaProfiles[_persona] ?? personaProfiles[_defaultPersona]!).sample;

  SupabaseClient get _client => Supabase.instance.client;

  /// Pemutar baru untuk setiap pemutaran.
  ///
  /// `audioplayers` di Android kadang menolak diam-diam saat pemutar yang
  /// sama dipakai untuk audio kedua (mis. setelah mikrofon dipakai). Dengan
  /// membuat pemutar baru tiap kali, jawaban kedua tetap terdengar.
  AudioPlayer _resetPlayer() {
    final old = _player;
    final next = AudioPlayer();
    _player = next;
    if (identical(old, next)) return next;
    unawaited(old.dispose().catchError((_) {}));
    return next;
  }

  /// Siapkan mesin TTS + muat config (cache 1 jam, fallback default).
  Future<void> init({bool forceRefresh = false, String? outletId}) async {
    await loadConfig(forceRefresh: forceRefresh);
    if (outletId != null && outletId.isNotEmpty) {
      await applyOutletPrefs(outletId);
    }
    if (_ready) return;
    try {
      await _selectVoice();
      await _tts.awaitSpeakCompletion(false);
      _tts.setCompletionHandler(() {
        final done = _speakDone;
        if (done != null && !done.isCompleted) done.complete();
      });
      _tts.setCancelHandler(() {
        final done = _speakDone;
        if (done != null && !done.isCompleted) done.complete();
      });
      _tts.setErrorHandler((_) {
        final done = _speakDone;
        if (done != null && !done.isCompleted) done.complete();
      });
      await _applyPersona(_persona);
      _ready = true;
    } catch (e) {
      _available = false;
      debugPrint('VoiceService.init TTS error: $e');
    }
  }

  /// Kumpulkan semua voice Indonesia di perangkat (di-cache).
  Future<List<VoiceOption>> _loadVoiceOptions({bool force = false}) async {
    if (!force && _voices.isNotEmpty) return _voices;
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return _voices;
      final out = <VoiceOption>[];
      for (final raw in voices) {
        if (raw is! Map) continue;
        final name = (raw['name'] ?? '').toString();
        final locale = (raw['locale'] ?? raw['language'] ?? '').toString();
        if (name.isEmpty) continue;
        final hay = '${name.toLowerCase()} ${locale.toLowerCase()}';
        final isId =
            locale.toLowerCase().replaceAll('_', '-').startsWith('id') ||
                hay.contains('indonesia');
        if (!isId) continue;
        out.add(VoiceOption(
          name: name,
          locale: locale.isEmpty ? 'id-ID' : locale,
          network: hay.contains('network'),
        ));
      }
      _voices = out;
    } catch (e) {
      debugPrint('VoiceService._loadVoiceOptions error: $e');
    }
    return _voices;
  }

  /// Pilih suara Indonesia terbaik yang tersedia di perangkat/browser.
  ///
  /// Android umumnya punya beberapa voice `id-ID` (mis. "id-id-x-idd-network"
  /// yang jauh lebih natural daripada voice offline default). Web Speech API
  /// memakai `voiceURI`/`name`, jadi pencocokan dilakukan pada nama + locale.
  Future<void> _selectVoice() async {
    await _tts.setLanguage('id-ID');
    try {
      final options = await _loadVoiceOptions(force: true);
      if (options.isEmpty) return;

      // 1. Suara pilihan owner (tersimpan di prefs) selalu menang.
      String? saved;
      try {
        final prefs = await SharedPreferences.getInstance();
        saved = prefs.getString(_voiceKey);
      } catch (_) {}
      if (saved != null && saved.isNotEmpty) {
        for (final o in options) {
          if (o.name == saved) {
            await _applyVoiceOption(o);
            return;
          }
        }
      }

      // 2. Belum ada pilihan: ikuti gender persona aktif, lalu natural.
      final best = _bestVoiceFor(
        options,
        gender: (personaProfiles[_persona] ?? personaProfiles[_defaultPersona]!)
            .gender,
      );
      if (best != null) await _applyVoiceOption(best);
    } catch (e) {
      debugPrint('VoiceService._selectVoice error: $e');
    }
  }

  /// Pilih voice terbaik: prioritas gender persona, lalu online/id-ID.
  VoiceOption? _bestVoiceFor(
    List<VoiceOption> options, {
    String? gender,
  }) {
    if (options.isEmpty) return null;
    VoiceOption? best;
    var bestScore = -1;
    for (final o in options) {
      final hay = '${o.name.toLowerCase()} ${o.locale.toLowerCase()}';
      var score = 0;
      if (o.locale.toLowerCase().replaceAll('_', '-').startsWith('id')) {
        score += 4;
      }
      if (hay.contains('id-id')) score += 3;
      if (o.network) score += 2;
      final isFemale = hay.contains('female') || hay.contains('wanita');
      final isMale = hay.contains('male') || hay.contains('pria');
      if (gender == 'female' && isFemale) score += 8;
      if (gender == 'male' && isMale) score += 8;
      if (gender == 'female' && isMale) score -= 6;
      if (gender == 'male' && isFemale) score -= 6;
      if (isFemale || isMale) score += 1;
      if (score > bestScore) {
        bestScore = score;
        best = o;
      }
    }
    return best;
  }

  Future<void> _applyVoiceOption(VoiceOption o) async {
    try {
      await _tts.setVoice({'name': o.name, 'locale': o.locale});
      _voiceName = o.name;
      _voiceLocale = o.locale;
      if (o.locale.isNotEmpty) await _tts.setLanguage(o.locale);
    } catch (e) {
      debugPrint('VoiceService._applyVoiceOption error: $e');
    }
  }

  /// Daftar suara Indonesia yang tersedia di perangkat/browser.
  ///
  /// Dipakai layar Dokter Bisnis agar owner bisa memilih sendiri warna suara
  /// (pria/wanita, offline/online) — akar keluhan "suaranya kaku semua".
  Future<List<VoiceOption>> listIndonesianVoices() async {
    try {
      await init();
      final out = List<VoiceOption>.from(await _loadVoiceOptions(force: true));
      out.sort((a, b) {
        if (a.network != b.network) return a.network ? -1 : 1;
        return a.label.compareTo(b.label);
      });
      return out;
    } catch (e) {
      debugPrint('VoiceService.listIndonesianVoices error: $e');
      return const [];
    }
  }

  /// Pilih suara perangkat secara manual (null = otomatis pilih terbaik).
  Future<void> selectVoice(VoiceOption? option) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (option == null) {
        await prefs.remove(_voiceKey);
        _voiceName = null;
        _voiceLocale = null;
        await _selectVoice();
        return;
      }
      await prefs.setString(_voiceKey, option.name);
      await _applyVoiceOption(option);
    } catch (e) {
      debugPrint('VoiceService.selectVoice error: $e');
    }
  }

  /// Terapkan persona aktif ke parameter TTS (rate/pitch/volume).
  Future<void> _applyPersona(String persona) async {
    final p = personaProfiles[persona] ?? personaProfiles[_defaultPersona]!;
    try {
      await _tts.setSpeechRate(p.rate);
      await _tts.setPitch(p.pitch);
      await _tts.setVolume(p.volume);

      // Bila owner BELUM memilih suara perangkat, ganti voice sesuai gender
      // persona (Bos Tegas = pria, Partner Santai = wanita) supaya tiap
      // persona terdengar benar-benar berbeda, bukan cuma tempo/nada.
      String? saved;
      try {
        final prefs = await SharedPreferences.getInstance();
        saved = prefs.getString(_voiceKey);
      } catch (_) {}
      if (saved == null || saved.isEmpty) {
        final options = await _loadVoiceOptions();
        final best = _bestVoiceFor(options, gender: p.gender);
        if (best != null && best.name != _voiceName) {
          await _applyVoiceOption(best);
        }
      }
    } catch (e) {
      debugPrint('VoiceService._applyPersona error: $e');
    }
  }

  /// Ganti persona suara (bos_tegas / partner_santai / analis_taktis).
  ///
  /// Dipanggil saat owner memilih persona di layar Dokter Bisnis agar warna
  /// suara ikut berubah, bukan hanya teks balasan AI.
  Future<void> setPersona(String persona, {bool persist = true}) async {
    final next = personaProfiles.containsKey(persona)
        ? persona
        : _defaultPersona;
    _persona = next;
    await _applyPersona(next);
    if (persist) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_personaKey, next);
      } catch (_) {}
    }
  }

  /// Muat persona tersimpan (dipanggil sekali saat init layar Dokter Bisnis).
  Future<void> restorePersona() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_personaKey);
      if (saved != null && personaProfiles.containsKey(saved)) {
        _persona = saved;
      }
    } catch (_) {}
    await _applyPersona(_persona);
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
    await speak(buf.toString(), priority: true);
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

  /// Komentar proaktif Dokter Bisnis soal kondisi toko (maks 1x per hari).
  Future<void> announceShopFloorComment(String text, {String? outletId}) async {
    if (outletId != null && outletId.isNotEmpty) {
      await applyOutletPrefs(outletId);
    }
    if (!available || !_config.shopFloor) return;
    final clean = text.trim();
    if (clean.isEmpty) return;
    await init();
    if (!available) return;
    final now = DateTime.now();
    final sp = await SharedPreferences.getInstance();
    final key = 'kasirgo_voice_shopfloor_comment_${_outletId ?? 'global'}_'
        '${now.year}${now.month}${now.day}';
    if (sp.getBool(key) == true) return;
    await sp.setBool(key, true);
    await speak(clean);
  }

  /// Teguran keras bergaya bos saat kasus macet melewati batas kritis.
  Future<void> announceBossEscalation(String text, {String? outletId}) async {
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

  /// Sapaan saat membuka layar Dokter Bisnis (maks 1x per hari per persona).
  Future<void> greetDoctorOpen({
    String? outletId,
    String? persona,
    String? ownerName,
  }) async {
    if (outletId != null && outletId.isNotEmpty) {
      await applyOutletPrefs(outletId);
    }
    if (!available || !_config.sapaanAwal) return;
    await init();
    if (!available) return;
    final now = DateTime.now();
    final hour = now.hour;
    final part = hour < 11
        ? 'pagi'
        : hour < 15
            ? 'siang'
            : hour < 19
                ? 'sore'
                : 'malam';
    final who = (ownerName?.trim().isNotEmpty ?? false)
        ? ownerName!.trim()
        : 'Bos';
    final tone = (persona ?? _persona).trim();
    await setPersona(tone, persist: false);
    final tail = tone == 'partner_santai'
        ? 'Saya siap temani, mau mulai dari mana?'
        : tone == 'analis_taktis'
            ? 'Saya sudah siapkan datanya. Mulai dari mana?'
            : 'Ada yang bisa saya kerjakan hari ini?';
    final text = 'Selamat $part, $who. $tail';
    final sp = await SharedPreferences.getInstance();
    final key = 'kasirgo_voice_doctor_greet_${_outletId ?? 'global'}_'
        '${tone}_${now.year}${now.month}${now.day}';
    if (sp.getBool(key) == true) return;
    await sp.setBool(key, true);
    await speak(text);
  }

  /// Ucapkan teks bebas (dipakai briefing/ucapan lain).
  /// [awaitCompletion] true -> Future selesai setelah TTS selesai bicara
  /// (dipakai voice loop agar mikrofon baru aktif setelah suara habis).
  /// Mengembalikan true bila suara benar-benar diputar/dibacakan.
  ///
  /// Semua ucapan berjalan berurutan (satu antrean): pengumuman tidak akan
  /// memotong jawaban yang sedang dibacakan, jadi suara selalu sampai habis.
  ///
  /// [priority] true (mis. konfirmasi pembayaran POS): memotong antrean dan
  /// mengakhiri ucapan yang sedang berjalan karena informasi bisnisnya tidak
  /// boleh menunggu.
  Future<bool> speak(
    String text, {
    bool awaitCompletion = false,
    bool priority = false,
  }) async {
    if (!available) return false;
    final clean = _naturalize(text);
    if (clean.isEmpty) return false;
    if (priority) await stop();
    final epoch = _speakEpoch;
    final job = _speakChain.then(
      (_) => _doSpeak(clean, awaitCompletion: awaitCompletion, epoch: epoch),
    );
    _speakChain = job.then<void>((_) {}, onError: (Object _) {});
    return await job;
  }

  /// Isi ucapan yang sebenarnya, dijalankan sesuai antrean [speak].
  Future<bool> _doSpeak(
    String clean, {
    bool awaitCompletion = false,
    required int epoch,
  }) async {
    if (epoch != _speakEpoch) return false;
    await init();
    if (!available) return false;
    if (await _speakCloud(clean, awaitCompletion: awaitCompletion)) return true;
    try {
      await _tts.stop();
      await _applyPersona(_persona);
      await _ensureIndonesianLanguage();
      if (!awaitCompletion) {
        await _tts.speak(clean);
        return true;
      }
      final done = Completer<void>();
      _speakDone = done;
      await _tts.speak(clean);
      var completed = true;
      await done.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          completed = false;
        },
      );
      if (identical(_speakDone, done)) _speakDone = null;
      return completed;
    } catch (e) {
      debugPrint('VoiceService.speak error: $e');
      return false;
    }
  }

  /// Pastikan mesin TTS perangkat memakai bahasa Indonesia.
  ///
  /// Sebagian HP hanya punya paket suara `id` (bukan `id-ID`). Tanpa
  /// pemeriksaan ini `speak()` bisa diam saja pada jawaban berikutnya.
  Future<void> _ensureIndonesianLanguage() async {
    try {
      final target = _voiceLocale ?? 'id-ID';
      final ok = await _tts.isLanguageAvailable(target);
      if (ok == true || ok == 1) return;
      final fallbackOk = await _tts.isLanguageAvailable('id');
      if (fallbackOk == true || fallbackOk == 1) {
        await _tts.setLanguage('id');
      }
    } catch (_) {}
  }

  /// Suara manusia (neural) dari Edge Function `tts_speak`.
  ///
  /// Server mengirim audio per kalimat (`segments`) beserta jeda antar
  /// kalimat. Jeda itulah yang membuat suara terdengar bernapas seperti
  /// manusia, bukan satu blok datar.
  ///
  /// Mengembalikan true bila audio cloud berhasil diputar. Bila gagal
  /// (offline, kuota, EF error) pemanggil melanjutkan ke TTS perangkat.
  Future<bool> _speakCloud(
    String text, {
    bool awaitCompletion = false,
  }) async {
    if (!_cloudOn) return false;
    final fetched = await _fetchCloudAudio(text);
    if (fetched == null) {
      _noteCloudFail();
      return false;
    }
    _cloudFail = 0;
    final data = fetched.$1;
    final segments = fetched.$2;

    final profile =
        personaProfiles[_persona] ?? personaProfiles[_defaultPersona]!;
    final rate = (data['playback_rate'] as num?)?.toDouble() ??
        profile.cloudRate;

    final gen = ++_speakGen;
    final total = segments.fold<int>(0, (a, s) => a + s.bytes.length);
    final totalPause = segments.fold<int>(0, (a, s) => a + s.pauseMs);
    // EF mengirim MP3 48 kbps = 6000 byte/detik, jadi di rate 1.0 durasi
    // audionya `total / 6` ms. Budget lama (`8000 + total ~/ 12`) hanya
    // setengah durasi asli: Future selesai sebelum audio habis, voice loop
    // langsung membuka mikrofon, dan suara terpotong di tengah kalimat.
    final msPerByte = 1000.0 / (6000.0 * rate);
    final budget = (12000 + total * msPerByte + totalPause).ceil();

    for (var attempt = 0; attempt < 2; attempt++) {
      if (gen != _speakGen) return true;
      final player = _resetPlayer();
      try {
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setPlaybackRate(rate.clamp(0.5, 1.5));
        // Tandai sebagai ucapan asisten agar focus audio Android (mis. saat
        // mikrofon baru terbuka) tidak meredupkan/mem-jeda jawaban.
        await player.setAudioContext(AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.assistant,
          ),
        ));
      } catch (_) {}

      if (!awaitCompletion) {
        unawaited(_playSegments(segments, gen, player, msPerByte));
        return true;
      }

      var played = true;
      final done = Completer<void>();
      _speakDone = done;
      unawaited(_playSegments(segments, gen, player, msPerByte).then((ok) {
        played = ok;
        if (!done.isCompleted) done.complete();
      }));
      await done.future.timeout(
        Duration(milliseconds: budget),
        onTimeout: () {},
      );
      if (identical(_speakDone, done)) _speakDone = null;
      if (played || gen != _speakGen) return played;
      debugPrint('VoiceService: pemutaran cloud gagal, coba ulang sekali.');
    }
    return false;
  }

  /// Ambil audio cloud dari Edge Function `tts_speak`.
  ///
  /// Endpoint suara neural bersifat best-effort, jadi satu kegagalan
  /// (mis. koneksi WebSocket putus) dicoba ulang sekali sebelum klien
  /// jatuh ke TTS perangkat. Tanpa ini jawaban kedua bisa diam saja.
  Future<(Map, List<_SpeechSegment>)?> _fetchCloudAudio(String text) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await _client.functions.invoke(
          'tts_speak',
          body: {'text': text, 'persona': _persona},
        );
        final data = res.data;
        if (data is Map) {
          final segments = _parseSegments(data);
          if (segments.isNotEmpty) return (data, segments);
        }
        debugPrint('VoiceService: respons tts_speak kosong.');
      } catch (e) {
        debugPrint('VoiceService._speakCloud error: $e');
      }
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    return null;
  }

  /// Mainkan potongan audio berurutan dengan jeda alami antar kalimat.
  /// [msPerByte] = lama audio per byte sesuai rate pemutaran, supaya batas
  /// tiap segmen tidak lebih pendek dari durasi aslinya. Mengembalikan
  /// false bila audio gagal diputar sehingga pemanggil bisa jatuh ke TTS
  /// perangkat.
  Future<bool> _playSegments(
    List<_SpeechSegment> segments,
    int gen,
    AudioPlayer player,
    double msPerByte,
  ) async {
    for (var i = 0; i < segments.length; i++) {
      if (gen != _speakGen || !identical(player, _player)) return true;
      final seg = segments[i];
      final done = player.onPlayerComplete.first;
      final started = Completer<bool>();
      final sub = player.onPlayerStateChanged.listen((state) {
        if ((state == PlayerState.playing ||
                state == PlayerState.completed) &&
            !started.isCompleted) {
          started.complete(true);
        }
      });
      try {
        await player.play(BytesSource(seg.bytes));
      } catch (_) {
        await sub.cancel();
        // play() ditolak saat audio lama dihentikan (AbortError). Bila
        // generasi sudah berganti, ini bukan kegagalan suara baru.
        if (gen != _speakGen) return true;
        return false;
      }
      final ok = await started.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );
      await sub.cancel();
      if (!ok) {
        if (gen != _speakGen) return true;
        debugPrint('VoiceService: audio cloud tidak mulai diputar.');
        return false;
      }
      await done.timeout(
        Duration(milliseconds: (6000 + seg.bytes.length * msPerByte).ceil()),
        onTimeout: () {},
      ).catchError((_) {});
      if (gen != _speakGen || !identical(player, _player)) return true;
      if (i < segments.length - 1 && seg.pauseMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: seg.pauseMs));
      }
    }
    return true;
  }

  /// Ambil daftar potongan audio dari respons EF. Bila server versi lama
  /// hanya mengirim `audio` tunggal, bungkus sebagai satu segmen.
  List<_SpeechSegment> _parseSegments(Map data) {
    final out = <_SpeechSegment>[];
    final raw = data['segments'];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final b64 = item['audio'];
        if (b64 is! String || b64.isEmpty) continue;
        final bytes = base64Decode(b64);
        if (bytes.length < 200) continue;
        final pause = (item['pause_ms'] as num?)?.toInt() ?? 0;
        // Tempo tiap persona juga memengaruhi panjang jeda: "Bos Tegas"
        // lebih pelan dan berwibawa, "Partner Santai" lebih mengalir.
        final scale = switch (_persona) {
          'bos_tegas' => 1.18,
          'analis_taktis' => 1.08,
          _ => 0.95,
        };
        out.add(
          _SpeechSegment(bytes, (pause * scale).round().clamp(0, 900)),
        );
      }
    }
    if (out.isNotEmpty) return out;

    final b64 = data['audio'];
    if (b64 is! String || b64.isEmpty) return const [];
    final bytes = base64Decode(b64);
    if (bytes.length < 500) return const [];
    return [_SpeechSegment(bytes, 0)];
  }

  void _noteCloudFail() {
    _cloudFail++;
    if (_cloudFail >= 3 && _cloudOn) {
      _cloudOn = false;
      debugPrint('VoiceService: suara cloud nonaktif sementara, '
          'memakai TTS perangkat.');
    }
  }

  /// Bacakan contoh kalimat persona aktif (dipakai tombol "Dengar Contoh").
  Future<void> previewPersona(String persona, {bool awaitCompletion = true}) async {
    await setPersona(persona, persist: false);
    await speak(personaSample, awaitCompletion: awaitCompletion);
  }

  /// Rapikan teks agar TTS terdengar lebih luwes, bukan datar/kaku:
  /// singkatan diurai, simbol dibaca, dan kalimat panjang dipecah pada
  /// kata sambung supaya ada jeda alami.
  String _naturalize(String text) {
    var s = text.trim();
    if (s.isEmpty) return s;
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    s = s
        .replaceAll('&', ' dan ')
        .replaceAll('%', ' persen ')
        .replaceAll(RegExp(r'\bRp\.?\s*'), 'rupiah ')
        .replaceAll(RegExp(r'\bvs\.?\b', caseSensitive: false), 'dibanding')
        .replaceAll(RegExp(r'\bsdh\b', caseSensitive: false), 'sudah')
        .replaceAll(RegExp(r'\bblm\b', caseSensitive: false), 'belum')
        .replaceAll(RegExp(r'\btdk\b', caseSensitive: false), 'tidak')
        .replaceAll(RegExp(r'\byg\b', caseSensitive: false), 'yang')
        .replaceAll(RegExp(r'\bdgn\b', caseSensitive: false), 'dengan')
        .replaceAll(RegExp(r'\butk\b', caseSensitive: false), 'untuk')
        .replaceAll(RegExp(r'\bkrn\b', caseSensitive: false), 'karena');
    // Buang sisa markup markdown agar tidak dibacakan sebagai simbol.
    s = s
        .replaceAll(RegExp(r'[*_`#>]+'), ' ')
        .replaceAll(RegExp(r'\[(.*?)\]\((.*?)\)'), r'$1')
        .replaceAll(RegExp(r'https?://\S+'), ' ');
    // Singkatan nominal yang biasa diketik pemilik warung.
    s = s
        .replaceAllMapped(
            RegExp(r'(\d)\s*(rb|ribu)\b', caseSensitive: false),
            (m) => '${m.group(1)} ribu')
        .replaceAllMapped(
            RegExp(r'(\d)\s*(jt|juta)\b', caseSensitive: false),
            (m) => '${m.group(1)} juta')
        .replaceAll('±', ' sekitar ')
        .replaceAll('->', ' menjadi ')
        .replaceAll('=>', ' menjadi ');
    s = s.replaceAllMapped(
        RegExp(r'\s*([,;:])\s*'), (m) => '${m.group(1)} ');
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
    s = s.replaceAllMapped(RegExp(r'\s+([.!?])'), (m) => m.group(1) ?? '');
    for (final c in const ['tapi', 'tetapi', 'karena', 'supaya', 'jadi']) {
      s = s.replaceAllMapped(
        RegExp('([^,.!?])\\s+$c\\b', caseSensitive: false),
        (m) => '${m.group(1)}, $c',
      );
    }
    return s.trim();
  }

  Future<void> stop() async {
    _speakEpoch++;
    _speakGen++;
    final done = _speakDone;
    if (done != null && !done.isCompleted) done.complete();
    try {
      await _player.stop();
    } catch (_) {}
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
