import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction.dart';

/// Config partner pembiayaan dari Control Plane
/// (platform_configs 'fintech_partner', scope global).
class FintechConfig {
  final bool enabled;
  final String partnerName;
  final String applyUrl;
  final String waNumber;

  const FintechConfig({
    this.enabled = true,
    this.partnerName = 'Mitra Pembiayaan KasirGo',
    this.applyUrl = '',
    this.waNumber = '',
  });

  /// Channel pengajuan: link partner -> fallback WA manual -> null.
  String? get applyChannel {
    if (applyUrl.trim().isNotEmpty) return applyUrl.trim();
    final wa = waNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (wa.isNotEmpty) return 'https://wa.me/$wa';
    return null;
  }

  static const fallback = FintechConfig();

  factory FintechConfig.fromMap(Map<String, dynamic> m) {
    return FintechConfig(
      enabled: m['enabled'] is bool ? m['enabled'] as bool : true,
      partnerName: m['partner_name']?.toString() ?? 'Mitra Pembiayaan KasirGo',
      applyUrl: m['apply_url']?.toString() ?? '',
      waNumber: m['wa_number']?.toString() ?? '',
    );
  }
}

/// Profil arus kas untuk skor kelayakan modal.
/// Semua angka AGREGAT ANONIM - tanpa identitas pelanggan (UU PDP).
class CashFlowProfile {
  final double monthlyOmzet;
  final int txCount;
  final double avgBasket;
  final int activeMonths;
  final double consistency; // 0..1 bulan kuat / bulan aktif
  final double score; // 0..100
  final double suggestedPlafon;
  final int windowDays;

  const CashFlowProfile({
    required this.monthlyOmzet,
    required this.txCount,
    required this.avgBasket,
    required this.activeMonths,
    required this.consistency,
    required this.score,
    required this.suggestedPlafon,
    required this.windowDays,
  });

  static const empty = CashFlowProfile(
    monthlyOmzet: 0,
    txCount: 0,
    avgBasket: 0,
    activeMonths: 0,
    consistency: 0,
    score: 0,
    suggestedPlafon: 0,
    windowDays: 90,
  );

  /// Payload anonim untuk pengajuan (tanpa PII pelanggan).
  Map<String, dynamic> toPayload() => {
        'window_days': windowDays,
        'tx_count': txCount,
        'monthly_omzet': monthlyOmzet,
        'avg_basket': avgBasket,
        'active_months': activeMonths,
        'consistency': consistency,
        'score': score,
        'source': 'kasirgo_ai',
      };
}

/// Service Fintech Lead (Phase 10 / ST10-1).
///
/// Skor kelayakan dihitung LOKAL dari arus kas (omzet, jumlah transaksi,
/// konsistensi) - pola sederhana AI engine, tanpa kirim data pelanggan.
class FintechService {
  FintechService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const double _minPlafon = 500000;
  static const double _maxPlafon = 20000000;

  Future<FintechConfig> loadConfig() async {
    try {
      final res = await _client
          .from('platform_configs')
          .select('value')
          .eq('key', 'fintech_partner')
          .eq('scope', 'global')
          .order('version', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res != null && res['value'] != null) {
        return FintechConfig.fromMap(
            Map<String, dynamic>.from(res['value'] as Map));
      }
    } catch (e) {
      debugPrint('FintechService.loadConfig error: $e');
    }
    return FintechConfig.fallback;
  }

  /// Hitung profil arus kas 90 hari dari transaksi (lokal, anonim).
  CashFlowProfile computeCashFlow(List<Transaction> transactions,
      {int windowDays = 90}) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: windowDays));
    final txs = transactions
        .where((t) =>
            t.createdAt.isAfter(start) && t.createdAt.isBefore(now))
        .toList();

    if (txs.isEmpty) return CashFlowProfile.empty;

    // Omzet per bulan kalender.
    final omzetPerMonth = <String, double>{};
    final txPerMonth = <String, int>{};
    double totalOmzet = 0;
    for (final t in txs) {
      final key = '${t.createdAt.year}-${t.createdAt.month.toString().padLeft(2, '0')}';
      omzetPerMonth[key] = (omzetPerMonth[key] ?? 0) + t.finalAmount;
      txPerMonth[key] = (txPerMonth[key] ?? 0) + 1;
      totalOmzet += t.finalAmount;
    }

    final activeMonths = omzetPerMonth.length;
    final strongMonths =
        omzetPerMonth.keys.where((k) => (txPerMonth[k] ?? 0) >= 5).length;
    final consistency =
        activeMonths > 0 ? strongMonths / activeMonths : 0.0;
    final monthlyOmzet = totalOmzet / activeMonths;
    final avgBasket = totalOmzet / txs.length;

    // Skor 0-100: volume (60%) + konsistensi (40%).
    final volumeScore = (monthlyOmzet / 5000000).clamp(0.0, 1.0);
    final score = (volumeScore * 60 + consistency * 40).clamp(0.0, 100.0);

    // Plafon indikatif: 30% omzet bulanan, naik bila konsisten.
    var plafon = monthlyOmzet * 0.3 * (0.7 + 0.3 * consistency);
    if (txs.length < 10) plafon = plafon < _minPlafon ? plafon : _minPlafon;
    plafon = plafon.clamp(_minPlafon, _maxPlafon);
    // Bulatkan ke 50.000 terdekat.
    plafon = (plafon / 50000).roundToDouble() * 50000;

    return CashFlowProfile(
      monthlyOmzet: monthlyOmzet,
      txCount: txs.length,
      avgBasket: avgBasket,
      activeMonths: activeMonths,
      consistency: consistency,
      score: score,
      suggestedPlafon: plafon,
      windowDays: windowDays,
    );
  }

  String buildRef() {
    final ts = DateTime.now();
    final ymd =
        '${ts.year.toString().substring(2)}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}';
    return 'FIN-$ymd-${(ts.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';
  }

  String buildWaLink(String waNumber, String partnerName, String outletName,
      double amount, int tenor) {
    final wa = waNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final text = Uri.encodeComponent(
        'Halo $partnerName, saya $outletName ingin mengajukan modal usaha '
        'sebesar Rp ${amount.toStringAsFixed(0)} dengan tenor $tenor bulan '
        '(diajukan via KasirGo).');
    return 'https://wa.me/$wa?text=$text';
  }

  Future<bool> submitLead({
    required String outletId,
    required String userId,
    required String partner,
    required double amountRequested,
    required int tenorMonths,
    required CashFlowProfile profile,
    String? note,
  }) async {
    try {
      await _client.from('fintech_leads').insert({
        'outlet_id': outletId,
        'user_id': userId,
        'partner': partner,
        'amount_requested': amountRequested,
        'tenor_months': tenorMonths,
        'status': 'apply',
        'ref': buildRef(),
        'eligibility_score': profile.score,
        'payload': profile.toPayload(),
        'note': ?note,
      });
      return true;
    } catch (e) {
      debugPrint('FintechService.submitLead error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getLeads(String outletId,
      {int limit = 30}) async {
    try {
      final res = await _client
          .from('fintech_leads')
          .select()
          .eq('outlet_id', outletId)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('FintechService.getLeads error: $e');
      return [];
    }
  }
}
