/// Implementasi native: Google ML Kit (gratis, on-device).
/// Text recognition untuk membaca NIK/nama KTP, face detection untuk
/// memastikan foto KTP memuat wajah asli dan selfie memuat wajah.
library;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../utils/kyc_checks.dart';

class KtpOcrResult {
  final String text;
  final String? nik;
  final String? name;
  const KtpOcrResult({this.text = '', this.nik, this.name});
}

const bool kycMlAvailable = true;

Future<KtpOcrResult> ocrKtp(String imagePath) async {
  final text = await _recognize(imagePath);
  return KtpOcrResult(
    text: text,
    nik: extractNikFromText(text),
    name: extractNameFromText(text),
  );
}

/// Cek apakah teks OCR memuat penanda KTP asli (anti screenshot/gambar asal).
/// KTP asli hampir selalu memuat salah satu label: PROVINSI, KARTU TANDA
/// PENDUDUK / KTP, REPUBLIK INDONESIA, GOL.DARAH, atau NIK.
bool ktpTextLooksReal(String text) {
  final up = text.toUpperCase();
  const markers = [
    'PROVINSI',
    'KARTU TANDA PENDUDUK',
    'KTP',
    'REPUBLIK INDONESIA',
    'GOL.DARAH',
    'GOL DARAH',
    'NIK',
  ];
  return markers.any(up.contains);
}

Future<String> _recognize(String imagePath) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final input = InputImage.fromFilePath(imagePath);
    final result = await recognizer.processImage(input);
    return result.text;
  } catch (_) {
    return '';
  } finally {
    await recognizer.close();
  }
}

/// Jumlah wajah terdeteksi pada gambar. -1 bila gagal/mesin tak mendukung.
Future<int> countFaces(String imagePath) async {
  final detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.1,
    ),
  );
  try {
    final input = InputImage.fromFilePath(imagePath);
    final faces = await detector.processImage(input);
    return faces.length;
  } catch (_) {
    return -1;
  } finally {
    await detector.close();
  }
}

Future<bool> hasFace(String imagePath) async => (await countFaces(imagePath)) > 0;