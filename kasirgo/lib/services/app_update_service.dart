import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/constants.dart';

class AppReleaseInfo {
  final String? id;
  final String platform;
  final String version;
  final int buildNumber;

  /// Map ABI -> URL APK. Kunci: 'arm64', 'armeabi_v7a', 'x86_64'.
  final Map<String, String> files;
  final String? guideUrl;
  final String changelog;
  final bool forceUpdate;
  final String? publishedAt;

  const AppReleaseInfo({
    this.id,
    required this.platform,
    required this.version,
    required this.buildNumber,
    this.files = const {},
    this.guideUrl,
    this.changelog = '',
    this.forceUpdate = false,
    this.publishedAt,
  });

  bool get hasGuide => (guideUrl ?? '').trim().isNotEmpty;

  /// URL APK untuk ABI tertentu, atau null bila tidak tersedia.
  String? fileUrlFor(String abi) {
    final u = files[abi];
    return (u != null && u.trim().isNotEmpty) ? u : null;
  }

  /// True bila nomor build rilis lebih baru daripada build aplikasi saat ini.
  bool isNewer(int currentBuild) => buildNumber > currentBuild;

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'];
    final Map<String, String> files = <String, String>{};
    if (rawFiles is Map) {
      rawFiles.forEach((k, v) {
        if (v != null) files[k.toString()] = v.toString();
      });
    }
    return AppReleaseInfo(
      id: json['id']?.toString(),
      platform: (json['platform'] ?? 'web').toString(),
      version: (json['version'] ?? '').toString(),
      buildNumber: (json['build_number'] as num?)?.toInt() ?? 0,
      files: files,
      guideUrl: json['guide_url']?.toString(),
      changelog: (json['changelog'] ?? '').toString(),
      forceUpdate: json['force_update'] == true,
      publishedAt: json['published_at']?.toString(),
    );
  }
}

/// Sumber data pembaruan aplikasi (Android APK per ABI / Web) dari tabel
/// `app_releases`.
class AppUpdateService {
  final SupabaseClient _db;

  AppUpdateService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  String get _platform => kIsWeb ? 'web' : 'android';

  Future<AppReleaseInfo?> latest() => _fetch(_platform);

  /// Rilis Android terbaru (untuk layar "unduh APK" di web), terlepas dari
  /// platform perangkat saat ini.
  Future<AppReleaseInfo?> latestAndroid() => _fetch('android');

  Future<AppReleaseInfo?> _fetch(String platform) async {
    final res = await _db.rpc('get_latest_app_release', params: {
      'p_platform': platform,
    });
    if (res == null) return null;
    if (res is Map) return AppReleaseInfo.fromJson(Map<String, dynamic>.from(res));
    if (res is List && res.isNotEmpty && res.first is Map) {
      return AppReleaseInfo.fromJson(Map<String, dynamic>.from(res.first as Map));
    }
    return null;
  }

  /// Cek pembaruan; hanya mengembalikan rilis yang lebih baru dari build saat ini.
  Future<AppReleaseInfo?> checkForUpdate() async {
    try {
      final rel = await latest();
      if (rel == null) return null;
      return rel.isNewer(AppConstants.appBuildNumber) ? rel : null;
    } catch (_) {
      return null;
    }
  }
}