/// Stub web: tanpa ML Kit. Kembalikan hasil kosong agar UI pakai input manual.
library;

class KtpOcrResult {
  final String text;
  final String? nik;
  final String? name;
  const KtpOcrResult({this.text = '', this.nik, this.name});
}

/// true bila perangkat mendukung OCR/face match on-device (native).
const bool kycMlAvailable = false;

Future<KtpOcrResult> ocrKtp(String imagePath) async =>
    const KtpOcrResult();

/// Cek apakah teks OCR memuat penanda KTP asli (anti screenshot/gambar asal).
/// Web stub: tidak ada OCR -> selalu true (fallback input manual).
bool ktpTextLooksReal(String text) => true;

/// Deteksi jumlah wajah pada sebuah gambar (untuk validasi selfie).
Future<int> countFaces(String imagePath) async => -1;

/// true bila ada minimal 1 wajah pada foto KTP (foto orang asli).
Future<bool> hasFace(String imagePath) async => false;