/// Implementasi web: unduh file via anchor blob.
/// dart:html deprecated di Flutter baru tapi tetap didukung build web release.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
library;

import 'dart:html' as html;
import 'dart:typed_data';

Future<void> webDownload(Uint8List bytes, String filename) async {
  final mime = filename.toLowerCase().endsWith('.pdf')
      ? 'application/pdf'
      : 'application/octet-stream';
  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
