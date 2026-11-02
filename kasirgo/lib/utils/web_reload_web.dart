// ignore_for_file: avoid_web_libraries_in_flutter
library;

import 'dart:html' as html;

/// Muat ulang aplikasi web (dipakai saat update tersedia di platform web).
Future<void> webReload() async {
  html.window.location.reload();
}