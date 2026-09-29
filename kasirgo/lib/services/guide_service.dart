import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supporter_service.dart';

/// Jenis konten panduan.
enum GuideKind { pdf, video, unknown }

GuideKind guideKindFrom(String? value) {
  switch ((value ?? '').toLowerCase()) {
    case 'pdf':
      return GuideKind.pdf;
    case 'video':
    case 'youtube':
      return GuideKind.video;
    default:
      return GuideKind.unknown;
  }
}

class GuideItem {
  final String id;
  final String title;
  final GuideKind kind;
  final String category;
  final String role;
  final String? url;
  final String? fileKey;
  final String? thumbnailKey;
  final int sortOrder;
  final String? r2Base;

  const GuideItem({
    required this.id,
    required this.title,
    required this.kind,
    required this.category,
    required this.role,
    this.url,
    this.fileKey,
    this.thumbnailKey,
    this.sortOrder = 0,
    this.r2Base,
  });

  /// URL efektif untuk dibuka/diunduh.
  String? get sourceUrl {
    if (url != null && url!.isNotEmpty) return url;
    if (fileKey != null && fileKey!.isNotEmpty) {
      if (fileKey!.startsWith('http')) return fileKey;
      if (r2Base != null && r2Base!.isNotEmpty) {
        return '${r2Base!.replaceAll(RegExp(r'/+$'), '')}/$fileKey';
      }
      return fileKey;
    }
    return null;
  }

  String? get thumbnailUrl {
    if (thumbnailKey == null || thumbnailKey!.isEmpty) return null;
    if (thumbnailKey!.startsWith('http')) return thumbnailKey;
    if (r2Base != null && r2Base!.isNotEmpty) {
      return '${r2Base!.replaceAll(RegExp(r'/+$'), '')}/$thumbnailKey';
    }
    return null;
  }

  factory GuideItem.fromMap(Map<String, dynamic> map, {String? r2Base}) => GuideItem(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        kind: guideKindFrom(map['kind']?.toString()),
        category: map['category']?.toString() ?? 'umum',
        role: map['role']?.toString() ?? 'all',
        url: map['url']?.toString(),
        fileKey: map['file_key']?.toString(),
        thumbnailKey: map['thumbnail_key']?.toString(),
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
        r2Base: r2Base,
      );

  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'title': title,
        'kind': kind.name,
        'category': category,
        'role': role,
        'url': url,
        'file_key': fileKey,
        'thumbnail_key': thumbnailKey,
        'sort_order': sortOrder,
        'r2_base': r2Base,
      };

  factory GuideItem.fromCacheJson(Map<String, dynamic> map) => GuideItem(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        kind: guideKindFrom(map['kind']?.toString()),
        category: map['category']?.toString() ?? 'umum',
        role: map['role']?.toString() ?? 'all',
        url: map['url']?.toString(),
        fileKey: map['file_key']?.toString(),
        thumbnailKey: map['thumbnail_key']?.toString(),
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
        r2Base: map['r2_base']?.toString(),
      );
}

/// Servis panduan: baca `guide_items` aktif + config `guide`, cache offline.
class GuideService {
  final SupabaseClient _client;
  GuideService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  static const _cacheKey = 'guide_items_cache_v1';
  static const _cacheTsKey = 'guide_items_cache_ts_v1';
  static const Map<String, dynamic> fallbackConfig = {
    'default_category': 'umum',
    'show_in_settings': true,
  };

  Future<Map<String, dynamic>> getConfig() =>
      SupporterService().getConfig('guide', fallback: fallbackConfig);

  /// Daftar panduan (server -> cache -> kosong). Selalu kembalikan list.
  Future<List<GuideItem>> loadItems({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_cacheTsKey) ?? 0;
    final fresh = DateTime.now().millisecondsSinceEpoch - ts < 15 * 60 * 1000;

    if (!force && fresh) {
      final cached = _readCache(prefs);
      if (cached != null) return cached;
    }

    try {
      final cfg = await getConfig();
      final r2Base = cfg['r2_base_url']?.toString();
      final res = await _client
          .from('guide_items')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      final items = (res as List)
          .map((e) => GuideItem.fromMap(Map<String, dynamic>.from(e as Map), r2Base: r2Base))
          .toList();
      await prefs.setString(
          _cacheKey, jsonEncode(items.map((e) => e.toCacheJson()).toList()));
      await prefs.setInt(_cacheTsKey, DateTime.now().millisecondsSinceEpoch);
      return items;
    } catch (_) {
      return _readCache(prefs) ?? <GuideItem>[];
    }
  }

  List<GuideItem>? _readCache(SharedPreferences prefs) {
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => GuideItem.fromCacheJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Path file PDF yang sudah di-cache lokal (mobile). Null bila belum ada / web.
  Future<String?> cachedPdfPath(GuideItem item) async {
    if (kIsWeb || item.kind != GuideKind.pdf) return null;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/guides/${item.id}.pdf');
      return await file.exists() ? file.path : null;
    } catch (_) {
      return null;
    }
  }

  /// Unduh PDF ke cache lokal (mobile). Kembalikan path, atau null di web/gagal.
  Future<String?> downloadPdf(GuideItem item) async {
    if (kIsWeb || item.kind != GuideKind.pdf) return null;
    final url = item.sourceUrl;
    if (url == null || url.isEmpty || !url.startsWith('http')) return null;
    try {
      final dir = await getApplicationSupportDirectory();
      final guideDir = Directory('${dir.path}/guides');
      if (!await guideDir.exists()) await guideDir.create(recursive: true);
      final file = File('${guideDir.path}/${item.id}.pdf');
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        await file.writeAsBytes(res.bodyBytes);
        return file.path;
      }
    } catch (_) {}
    return null;
  }
}
