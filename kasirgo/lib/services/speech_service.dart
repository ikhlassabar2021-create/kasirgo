import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Hasil transkrip suara.
/// [finalResult] true bila pengguna sudah berhenti bicara.
typedef SpeechTranscript = void Function(String text, bool finalResult);

/// Layanan input suara (Speech-to-Text) untuk Dokter Bisnis 3.0.
///
/// Dipakai agar owner gaptek bisa "ngobrol" dengan Dokter tanpa mengetik.
/// Bahasa dipaksa Indonesia (`id_ID`). Bila perangkat/browser tidak punya
/// mesin STT, semua pemanggilan aman (mengembalikan false, tanpa crash).
class SpeechService {
  SpeechService._internal();
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;

  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;
  bool _available = false;
  bool _listening = false;
  String? _error;

  bool get isListening => _listening;
  bool get available => _available;
  String? get error => _error;

  /// Siapkan mesin STT + minta izin mikrofon (sekali saja).
  Future<bool> init() async {
    if (_initialized) return _available;
    _initialized = true;
    try {
      _available = await _stt.initialize(
        onError: (SpeechRecognitionError e) {
          _error = _friendlyError(e.errorMsg);
          _listening = false;
          debugPrint('SpeechService error: ${e.errorMsg}');
        },
        onStatus: (String status) {
          if (status == 'done' || status == 'notListening') {
            _listening = false;
          }
        },
      );
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

  /// Mulai mendengarkan. [onResult] dipanggil untuk hasil sementara & final.
  Future<bool> start({required SpeechTranscript onResult}) async {
    _error = null;
    final ok = await init();
    if (!ok) return false;
    try {
      await _stt.listen(
        onResult: (SpeechRecognitionResult r) {
          final text = r.recognizedWords.trim();
          onResult(text, r.finalResult);
        },
        listenOptions: SpeechListenOptions(
          localeId: 'id_ID',
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 3),
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

  /// Selesaikan sesi dengar (hasil final tetap dikirim lewat callback).
  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
    _listening = false;
  }

  /// Batalkan sesi dengar tanpa mengirim hasil.
  Future<void> cancel() async {
    try {
      await _stt.cancel();
    } catch (_) {}
    _listening = false;
  }

  String _friendlyError(String raw) {
    final e = raw.toLowerCase();
    if (e.contains('permission') || e.contains('denied')) {
      return 'Izin mikrofon ditolak. Aktifkan izin mikrofon di pengaturan.';
    }
    if (e.contains('no_match') || e.contains('no match')) {
      return 'Suara belum terbaca. Coba bicara lebih jelas.';
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
    return 'Pengenal suara gagal. Coba lagi.';
  }
}
