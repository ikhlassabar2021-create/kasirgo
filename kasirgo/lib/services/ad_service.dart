import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supporter_service.dart';

/// Satu kreatif iklan sponsor (dari config `ads` di platform_configs).
class SponsorAd {
  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? ctaLabel;
  final String? url;
  final String? category;

  /// Banner disimpan LOKAL sebagai base64 (embedded di config), bukan storage.
  final String? imageBase64;
  final String? imageMime;

  /// Embed opsional dari Control Plane (kode HTML/script).
  final String? htmlCode;
  final String? scriptCode;
  final String mediaType;

  const SponsorAd({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.ctaLabel,
    this.url,
    this.category,
    this.imageBase64,
    this.imageMime,
    this.htmlCode,
    this.scriptCode,
    this.mediaType = 'image',
  });

  bool get hasImage => (imageUrl != null && imageUrl!.isNotEmpty) ||
      (imageBase64 != null && imageBase64!.isNotEmpty);

  /// Sumber gambar untuk `Image.network`: URL langsung atau data URI base64.
  String? get imageSrc {
    if (imageUrl != null && imageUrl!.isNotEmpty) return imageUrl;
    final b64 = imageBase64;
    if (b64 != null && b64.isNotEmpty) {
      if (b64.startsWith('http')) return b64;
      final mime = (imageMime != null && imageMime!.isNotEmpty)
          ? imageMime!
          : 'image/png';
      return 'data:$mime;base64,$b64';
    }
    return null;
  }

  /// Gambar ter-dekode utk `Image.memory` (paling andal utk base64 di web).
  Uint8List? get imageBytes {
    final b64 = imageBase64;
    if (b64 == null || b64.isEmpty || b64.startsWith('http')) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  factory SponsorAd.fromJson(Map<String, dynamic> json) {
    return SponsorAd(
      id: (json['id'] ?? json['title'] ?? json['name'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? 'Sponsor').toString(),
      subtitle: json['subtitle']?.toString() ?? json['description']?.toString(),
      imageUrl: json['image_url']?.toString() ?? json['image']?.toString(),
      ctaLabel: json['cta']?.toString() ??
          json['cta_label']?.toString() ??
          json['ctaLabel']?.toString(),
      url: json['url']?.toString() ??
          json['link']?.toString() ??
          json['target_url']?.toString(),
      category: json['category']?.toString(),
      imageBase64: json['image_base64']?.toString() ?? json['banner']?.toString(),
      imageMime: json['image_mime']?.toString(),
      htmlCode: json['html_code']?.toString(),
      scriptCode: json['script_code']?.toString(),
      mediaType: (json['media_type']?.toString() ?? 'image'),
    );
  }
}

/// Hasil keputusan tampil-iklan untuk satu outlet.
class AdDecision {
  final bool showAds;
  final bool adFree;
  final bool needsConsent;
  final List<SponsorAd> ads;

  const AdDecision({
    this.showAds = false,
    this.adFree = false,
    this.needsConsent = false,
    this.ads = const [],
  });
}

/// Service iklan sisi pelanggan (katalog online + QR meja).
///
/// Prinsip (Bagian 7.8 / ST7.8-6):
/// - config dibaca dari `platform_configs.ads` (cache + fallback, offline-safe)
/// - HANYA sisi pelanggan; owner TIDAK melihat iklan sama sekali
/// - Pendukung (ad_free) bebas iklan
/// - kategori judi/dewasa/pinjol DIBLOKIR
/// - consent UU PDP wajib sebelum iklan tampil
/// - creatives (banner lokal base64 / kode HTML) dari Control Plane
class AdService {
  AdService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String consentKey = 'ad_consent_state_v1';
  static const List<String> hardBlockedCategories = ['judi', 'dewasa', 'pinjol'];

  Future<Map<String, dynamic>> _adsConfig() =>
      SupporterService(client: _client)
          .getAdsConfig();

  // ---------------------------------------------------------------------------
  // Consent (UU PDP)
  // ---------------------------------------------------------------------------

  /// null = belum memutuskan, true = setuju, false = tolak.
  Future<bool?> getConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(consentKey);
    if (v == 'accepted') return true;
    if (v == 'declined') return false;
    return null;
  }

  Future<void> setConsent(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(consentKey, accepted ? 'accepted' : 'declined');
  }

  /// Hapus state consent (kembali ke "belum memutuskan").
  Future<void> clearConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(consentKey);
  }

  // ---------------------------------------------------------------------------
  // Status bebas iklan outlet (pelanggan anonim -> RPC publik)
  // ---------------------------------------------------------------------------

  Future<bool> isOutletAdFree(String outletId) async {
    try {
      final res = await _client
          .rpc('get_public_ad_state', params: {'p_outlet': outletId});
      final row = (res is List && res.isNotEmpty)
          ? Map<String, dynamic>.from(res.first as Map)
          : (res is Map ? Map<String, dynamic>.from(res) : null);
      if (row != null) {
        // ad_free langsung, atau status supporter aktif.
        return row['ad_free'] == true || row['is_supporter'] == true;
      }
    } catch (_) {
      // RPC belum ada -> coba jalur terautentikasi.
    }
    try {
      final ent = await SupporterService(client: _client)
          .getEntitlements(outletId);
      return ent.adFree || ent.isSupporter;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // KEPUTUSAN IKLAN
  // ---------------------------------------------------------------------------

  Set<String> _blockedFrom(Map<String, dynamic> adsConfig) {
    final raw = adsConfig['blocked_categories'];
    final set = <String>{...hardBlockedCategories};
    if (raw is List) {
      for (final c in raw) {
        final v = c.toString().trim().toLowerCase();
        if (v.isNotEmpty) set.add(v);
      }
    }
    return set;
  }

  bool _isBlocked(SponsorAd ad, Set<String> blocked) {
    final cat = (ad.category ?? '').toLowerCase();
    if (cat.isEmpty) return false;
    for (final b in blocked) {
      if (cat.contains(b)) return true;
    }
    final blob = '${ad.title} ${ad.subtitle ?? ''}'.toLowerCase();
    for (final b in blocked) {
      if (blob.contains(b)) return true;
    }
    return false;
  }

  /// Tentukan apakah iklan boleh tampil + kreatif yang lolos filter.
  Future<AdDecision> decide({
    required String outletId,
    bool isOwner = false,
    bool consentGiven = false,
  }) async {
    final cfg = await _adsConfig();
    final adFreeSupplier = cfg['ad_free_for_supporter'] != false;
    final consentRequired = cfg['consent_required'] != false;

    // Owner tidak melihat iklan sama sekali.
    if (isOwner) {
      return const AdDecision();
    }

    final adFree = await isOutletAdFree(outletId);
    if (adFree && adFreeSupplier) {
      return const AdDecision(adFree: true);
    }

    if (consentRequired && !consentGiven) {
      final stored = await getConsent();
      if (stored == null) {
        return const AdDecision(needsConsent: true);
      }
      if (stored == false) {
        // Sudah ditolak sebelumnya: slot hilang, TANPA kartu consent berulang.
        return const AdDecision();
      }
      // stored == true -> lanjut tampilkan iklan.
    }

    final blocked = _blockedFrom(cfg);

    // Kreatif dari Control Plane (banner lokal base64 / kode embed).
    final ads = <SponsorAd>[];
    final raw = cfg['creatives'] ?? cfg['sponsor_local'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          if (map['is_active'] == false) continue;
          final ad = SponsorAd.fromJson(map);
          if (!_isBlocked(ad, blocked)) ads.add(ad);
        }
      }
    }

    return AdDecision(
      showAds: ads.isNotEmpty,
      adFree: adFree,
      ads: ads,
    );
  }

  /// Saring kategori terblokir dari daftar mentah (dipakai unit test / admin).
  @visibleForTesting
  static List<Map<String, dynamic>> filterBlocked(
    List<Map<String, dynamic>> raw,
    List<String> blocked,
  ) {
    final set = <String>{
      ...hardBlockedCategories,
      ...blocked.map((e) => e.toLowerCase()),
    };
    return raw.where((item) {
      final cat = (item['category'] ?? '').toString().toLowerCase();
      return !set.any((b) => cat.contains(b));
    }).toList();
  }
}
