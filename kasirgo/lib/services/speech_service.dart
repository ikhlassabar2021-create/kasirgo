import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../utils/speech_text_utils.dart';

/// Hasil transkrip suara.
/// [finalResult] true bila pengguna sudah berhenti bicara.
typedef SpeechTranscript = void Function(String text, bool finalResult);

/// Perubahan level suara mikrofon (dB, makin besar makin keras).
typedef SpeechLevelListener = void Function(double level);

/// Layanan input suara (Speech-to-Text) untuk Dokter Bisnis 3.0.
///
/// Dipakai agar owner gaptek bisa "ngobrol" dengan Dokter tanpa mengetik.
/// Bahasa dipaksa Indonesia (`id-ID`) dengan locale yang dicocokkan ke daftar
/// locale perangkat/browser — bukan hardcode `id_ID` yang sering tidak dikenali
/// mesin STT sehingga jatuh ke bahasa default (akar transkrip ngawur).
///
/// Sesi dengar bersifat kontinu: bila mesin berhenti karena jeda, sesi
/// dilanjutkan otomatis dan hasilnya disambung, jadi kalimat panjang tidak
/// terpotong. Bila perangkat/browser tidak punya mesin STT, semua pemanggilan
/// aman (mengembalikan false, tanpa crash).
class SpeechService {
  SpeechService._internal();
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;

  /// Kandidat locale Indonesia, diurutkan dari yang paling spesifik.
  static const _localeCandidates = ['id-ID', 'id_ID', 'in-ID', 'id'];

  /// Kosakata khas warung/UMKM untuk membiaskan pengenalan (Android 13+).
  static const _contextualPhrases = [
    'omzet',
    'laba',
    'margin',
    'stok',
    'kulakan',
    'kasbon',
    'pelanggan',
    'diskon',
    'promo',
    'resep',
    'bundling',
    'QRIS',
    'tunai',
    'Dokter Bisnis',
    'KasirGo',
  ];

  static const _maxRestarts = 8;

  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;
  bool _available = false;
  bool _listening = false;
  bool _wantListening = false;
  int _restarts = 0;
  String? _error;
  String? _localeId;
  String _segmentBase = '';
  String _lastFinalText = '';
  Timer? _restartTimer;
  SpeechTranscript? _onResult;
  SpeechLevelListener? _onLevel;

  bool get isListening => _listening;
  bool get available => _available;
  String? get error => _error;
  String? get localeId => _localeId;

  /// Teks yang sudah terkumpul pada sesi dengar aktif.
  String get transcript => _segmentBase;

  /// Siapkan mesin STT + minta izin mikrofon (sekali saja).
  Future<bool> init() async {
    if (_initialized) return _available;
    _initialized = true;
    try {
      _available = await _stt.initialize(
        // Beri waktu lebih panjang agar kalimat terakhir tetap dikirim utuh
        // sebelum sesi dinyatakan selesai.
        finalTimeout: const Duration(seconds: 4),
        onError: (SpeechRecognitionError e) {
          _error = _friendlyError(e.errorMsg);
          _listening = false;
          debugPrint('SpeechService error: ${e.errorMsg}');
          _scheduleRestart();
        },
        onStatus: (String status) {
          if (status == 'listening') {
            _listening = true;
            _restarts = 0;
            return;
          }
          if (status == 'done' || status == 'notListening') {
            _listening = false;
            _scheduleRestart();
          }
        },
      );
      if (_available) await _resolveLocale();
    } catch (e) {
      _available = false;
      _error = 'Mesin pengenal suara tidak tersedia di perangkat ini.';
      debugPrint('SpeechService.init error: $e');
    }
    if (!_available) {
      _error ??= 'Mesin pengenal suara tidak tersedia di perangkat ini.';
    }
    return _available;
  }

  /// Cocokkan locale Indonesia yang benar-benar ada di perangkat.
  Future<void> _resolveLocale() async {
    try {
      final locales = await _stt.locales();
      for (final want in _localeCandidates) {
        final w = want.toLowerCase().replaceAll('_', '-');
        for (final l in locales) {
          final id = l.localeId.toLowerCase().replaceAll('_', '-');
          if (id == w) {
            _localeId = l.localeId;
            return;
          }
        }
      }
      for (final l in locales) {
        final id = l.localeId.toLowerCase().replaceAll('_', '-');
        if (id.startsWith('id') || id.startsWith('in')) {
          _localeId = l.localeId;
          return;
        }
      }
      // Jangan biarkan null: null = mesin STT memakai bahasa default
      // perangkat/browser (sering en-US) sehingga transkrip Indonesia ngawur.
      _localeId = 'id-ID';
    } catch (e) {
      debugPrint('SpeechService._resolveLocale error: $e');
      _localeId = 'id-ID';
    }
  }

  /// Mulai mendengarkan. [onResult] dipanggil untuk hasil sementara & final.
  ///
  /// [onSoundLevel] opsional untuk indikator level suara (sensitivitas).
  /// [reset] true (default) memulai transkrip baru; false melanjutkan.
  Future<bool> start({
    required SpeechTranscript onResult,
    SpeechLevelListener? onSoundLevel,
    bool reset = true,
  }) async {
    _error = null;
    _onResult = onResult;
    _onLevel = onSoundLevel;
    if (reset) {
      _segmentBase = '';
      _lastFinalText = '';
    }
    _restarts = 0;
    final ok = await init();
    if (!ok) return false;
    _wantListening = true;
    return _begin();
  }

  Future<bool> _begin() async {
    _restartTimer?.cancel();
    _restartTimer = null;
    if (!_wantListening) return false;
    try {
      await _stt.listen(
        onResult: _handleResult,
        onSoundLevelChange: (double level) => _onLevel?.call(level),
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          partialResults: true,
          // Jangan batalkan sesi saat error sementara (no-match/timeout);
          // sesi dilanjutkan otomatis agar pengguna tak perlu tekan mic lagi.
          cancelOnError: false,
          listenMode: ListenMode.dictation,
          autoPunctuation: true,
          listenFor: const Duration(minutes: 2),
          // 6 detik cukup untuk jeda berpikir tanpa memotong kalimat.
          pauseFor: const Duration(seconds: 6),
          contextualPhrases: _contextualPhrases,
        ),
      );
      _listening = true;
      return true;
    } catch (e) {
      _listening = false;
      _error = 'Gagal memulai mikrofon. Coba lagi.';
      debugPrint('SpeechService.start error: $e');
      return false;
    }
  }

  void _handleResult(SpeechRecognitionResult r) {
    final words = _clean(r.recognizedWords);
    final text = _clean(_merge(_segmentBase, words));
    if (r.finalResult) {
      _segmentBase = text;
      _restarts = 0;
      if (text.isEmpty || text == _lastFinalText) return;
      _lastFinalText = text;
      _onResult?.call(text, true);
      return;
    }
    if (text.isEmpty) return;
    _onResult?.call(text, false);
  }

  /// Lanjutkan sesi otomatis selama pengguna belum menekan berhenti.
  void _scheduleRestart() {
    if (!_wantListening || _restartTimer != null) return;
    if (_restarts >= _maxRestarts) {
      _wantListening = false;
      _error ??= 'Sesi suara berakhir. Tekan mikrofon untuk bicara lagi.';
      return;
    }
    _restarts++;
    _restartTimer = Timer(const Duration(milliseconds: 300), () {
      _restartTimer = null;
      if (!_wantListening || _stt.isListening) return;
      _begin();
    });
  }

  /// Selesaikan sesi dengar (hasil final tetap dikirim lewat callback).
  Future<void> stop() async {
    _wantListening = false;
    _restartTimer?.cancel();
    _restartTimer = null;
    try {
      await _stt.stop();
    } catch (_) {}
    _listening = false;
    final text = _clean(_segmentBase);
    if (text.isNotEmpty && text != _lastFinalText) {
      _lastFinalText = text;
      _onResult?.call(text, true);
    }
  }

  /// Batalkan sesi dengar tanpa mengirim hasil.
  Future<void> cancel() async {
    _wantListening = false;
    _restartTimer?.cancel();
    _restartTimer = null;
    try {
      await _stt.cancel();
    } catch (_) {}
    _listening = false;
    _segmentBase = '';
    _lastFinalText = '';
  }

  /// Sambung potongan baru ke transkrip lama (buang tumpang tindih).
  String _merge(String base, String words) =>
      mergeTranscriptSegments(base, words);

  String _clean(String raw) => cleanTranscript(raw);

  String _friendlyError(String raw) {
    final e = raw.toLowerCase();
    if (e.contains('permission') || e.contains('denied')) {
      return 'Izin mikrofon ditolak. Aktifkan izin mikrofon di pengaturan.';
    }
    if (e.contains('no_match') || e.contains('no match')) {
      return 'Suara belum terbaca. Coba bicara lebih dekat ke mikrofon.';
    }
    if (e.contains('network')) {
      return 'Pengenal suara butuh internet. Periksa koneksi Anda.';
    }
    if (e.contains('busy')) {
      return 'Mikrofon sedang dipakai aplikasi lain.';
    }
    if (e.contains('timeout')) {
      return 'Tidak ada suara terdeteksi. Coba lagi.';
    }
    if (e.contains('audio') || e.contains('client')) {
      return 'Mikrofon bermasalah. Coba tutup lalu buka lagi layar ini.';
    }
    return 'Pengenal suara gagal. Coba lagi.';
  }
}
