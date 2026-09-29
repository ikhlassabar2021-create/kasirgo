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

  const SponsorAd({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.ctaLabel,
    this.url,
    this.category,
  });

  factory SponsorAd.fromJson(Map<String, dynamic> json) {
    return SponsorAd(
      id: (json['id'] ?? json['title'] ?? json['name'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? 'Sponsor').toString(),
      subtitle: json['subtitle']?.toString() ?? json['description']?.toString(),
      imageUrl: json['image_url']?.toString() ?? json['image']?.toString(),
      ctaLabel: json['cta']?.toString() ?? json['cta_label']?.toString(),
      url: json['url']?.toString() ?? json['link']?.toString(),
      category: json['category']?.toString(),
    );
  }
}

/// Hasil keputusan tampil-iklan untuk satu outlet.
class AdDecision {
  final bool showAds;
  final bool adFree;
  final bool needsConsent;
  final List<SponsorAd> ads;
  final String provider;

  const AdDecision({
    this.showAds = false,
    this.adFree = false,
    this.needsConsent = false,
    this.ads = const [],
    this.provider = 'sponsor_lokal',
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
/// - sponsor_lokal diutamakan, adsterra fallback; tidak ada iklan tersembunyi
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
    final provider = (cfg['provider'] ?? 'sponsor_lokal').toString();
    final adFreeSupplier = cfg['ad_free_for_supporter'] != false;
    final consentRequired = cfg['consent_required'] != false;

    // Owner tidak melihat iklan sama sekali.
    if (isOwner) {
      return const AdDecision(provider: 'sponsor_lokal');
    }

    final adFree = await isOutletAdFree(outletId);
    if (adFree && adFreeSupplier) {
      return AdDecision(adFree: true, provider: provider);
    }

    if (consentRequired && !consentGiven) {
      return AdDecision(needsConsent: true, provider: provider);
    }

    final blocked = _blockedFrom(cfg);

    // Kumpulkan kreatif yang bisa dirender (sponsor lokal diutamakan).
    final ads = <SponsorAd>[];
    final sponsorLocal = cfg['sponsor_local'];
    if (sponsorLocal is List) {
      for (final item in sponsorLocal) {
        if (item is Map) {
          final ad = SponsorAd.fromJson(Map<String, dynamic>.from(item));
          if (!_isBlocked(ad, blocked)) ads.add(ad);
        }
      }
    }

    if (ads.isEmpty && provider == 'adsterra') {
      final key = (cfg['adsterra_key'] ?? '').toString();
      if (key.isNotEmpty) {
        // Kreatif Adsterra dirender oleh web shell; di app hanya penanda jujur
        // bahwa slot ini bersponsor (tidak ada iklan tersembunyi).
        ads.add(const SponsorAd(
          id: 'adsterra',
          title: 'Iklan sponsor',
          subtitle: 'Slot iklan mitra',
          ctaLabel: '',
        ));
      }
    }

    return AdDecision(
      showAds: ads.isNotEmpty,
      adFree: adFree,
      provider: provider,
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
