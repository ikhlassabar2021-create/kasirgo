import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

/// Lampiran berkas untuk Dokter Bisnis AI.
///
/// LLM yang dipakai KasirGo bersifat teks, jadi berkas diekstrak menjadi teks
/// di perangkat (offline, tanpa unggah ke server) lalu dikirim sebagai konteks
/// percakapan. Tidak ada berkas yang disimpan di Supabase Storage.
class DoctorFileAttachment {
  const DoctorFileAttachment({
    required this.name,
    required this.kind,
    required this.text,
    this.truncated = false,
  });

  final String name;
  final String kind;
  final String text;
  final bool truncated;

  int get chars => text.length;
}

/// Pembaca berkas lokal (PDF, Excel, CSV, TXT) untuk konteks Dokter Bisnis.
class DoctorFileService {
  static const int maxBytes = 5 * 1024 * 1024;
  static const int maxChars = 12000;

  static const supportedExtensions = <String>[
    'pdf',
    'xlsx',
    'xls',
    'csv',
    'txt',
  ];

  /// Buka dialog pilih berkas lalu ekstrak teksnya.
  ///
  /// Mengembalikan null bila pengguna membatalkan dialog.
  /// Melempar [DoctorFileException] bila berkas tidak didukung / terlalu besar.
  Future<DoctorFileAttachment?> pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedExtensions,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return null;
    final name = file.name;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const DoctorFileException('Berkas tidak dapat dibaca.');
    }
    return parse(name: name, bytes: bytes);
  }

  /// Ekstrak teks dari byte berkas. Dipisah agar mudah diuji.
  DoctorFileAttachment parse({required String name, required Uint8List bytes}) {
    if (bytes.length > maxBytes) {
      throw const DoctorFileException(
        'Berkas terlalu besar. Maksimal 5 MB ya.',
      );
    }
    final ext = _extension(name);
    String text;
    switch (ext) {
      case 'pdf':
        text = _pdfText(bytes);
        break;
      case 'xlsx':
      case 'xls':
        text = _excelText(bytes);
        break;
      case 'csv':
        text = _plainText(bytes);
        break;
      case 'txt':
        text = _plainText(bytes);
        break;
      default:
        throw DoctorFileException(
          'Format .$ext belum didukung. Gunakan PDF, Excel, CSV, atau TXT.',
        );
    }
    final clean = text.replaceAll('\u0000', ' ').trim();
    if (clean.isEmpty) {
      throw const DoctorFileException(
        'Isi berkas tidak terbaca. Coba berkas lain atau ketik datanya manual.',
      );
    }
    final truncated = clean.length > maxChars;
    return DoctorFileAttachment(
      name: name,
      kind: ext,
      text: truncated ? clean.substring(0, maxChars) : clean,
      truncated: truncated,
    );
  }

  String _extension(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return '';
    return name.substring(i + 1).toLowerCase();
  }

  String _plainText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  String _excelText(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final out = StringBuffer();
    var rows = 0;
    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null) continue;
      out.writeln('### Sheet: $table');
      for (final row in sheet.rows) {
        if (rows >= 300) break;
        final cells = row
            .map((c) => c?.value?.toString().trim() ?? '')
            .toList();
        if (cells.every((c) => c.isEmpty)) continue;
        out.writeln(cells.join(' | '));
        rows++;
      }
      if (rows >= 300) {
        out.writeln('... (dipotong, terlalu banyak baris)');
        break;
      }
    }
    return out.toString();
  }

  /// Ekstraktor PDF sederhana: buka stream (FlateDecode) lalu ambil operator
  /// teks `Tj`/`TJ`. Cukup untuk laporan/nota PDF umum tanpa font custom.
  String _pdfText(Uint8List bytes) {
    final raw = latin1.decode(bytes, allowInvalid: true);
    final out = StringBuffer();
    final streamRe = RegExp(r'stream\r?\n([\s\S]*?)endstream');
    for (final m in streamRe.allMatches(raw)) {
      final chunk = m.group(1) ?? '';
      String content = chunk;
      try {
        final decoded = const ZLibDecoder()
            .decodeBytes(latin1.encode(chunk), verify: false);
        content = latin1.decode(decoded, allowInvalid: true);
      } catch (_) {
        // Stream tidak terkompresi / bukan Flate: pakai apa adanya.
      }
      final text = _pdfOperators(content);
      if (text.trim().isNotEmpty) {
        out.writeln(text);
      }
    }
    return out.toString();
  }

  String _pdfOperators(String content) {
    final out = StringBuffer();
    final tjRe = RegExp("\\([^()]*\\)\\s*(?:Tj|TJ|'|\")");
    final arrayRe = RegExp(r'\[[^\]]*\]\s*TJ');
    for (final m in arrayRe.allMatches(content)) {
      final parts = RegExp(r'\([^()]*\)')
          .allMatches(m.group(0) ?? '')
          .map((s) => _pdfUnescape(s.group(0)!));
      out.write(parts.join());
      out.write(' ');
    }
    for (final m in tjRe.allMatches(content)) {
      final s = m.group(0)!;
      final end = s.indexOf(')');
      if (end <= 0) continue;
      out.write(_pdfUnescape(s.substring(0, end + 1)));
      out.write(' ');
    }
    return out.toString();
  }

  String _pdfUnescape(String token) {
    if (token.length < 2) return '';
    var s = token.substring(1, token.length - 1);
    s = s
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\n')
        .replaceAll(r'\t', ' ')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\');
    return s;
  }
}

class DoctorFileException implements Exception {
  const DoctorFileException(this.message);
  final String message;

  @override
  String toString() => message;
}
