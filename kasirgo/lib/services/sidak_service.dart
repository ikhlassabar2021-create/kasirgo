import 'package:supabase_flutter/supabase_flutter.dart';

/// Temuan hasil sidak (audit internal) yang ditampilkan ke owner.
class SidakFinding {
  final String code;
  final String title;
  final String detail;
  final String severity; // tinggi | sedang | rendah
  final double? amount;

  const SidakFinding({
    required this.code,
    required this.title,
    required this.detail,
    this.severity = 'sedang',
    this.amount,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'title': title,
        'detail': detail,
        'severity': severity,
        'amount': amount,
      };

  factory SidakFinding.fromJson(Map<String, dynamic> json) => SidakFinding(
        code: (json['code'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        detail: (json['detail'] ?? '').toString(),
        severity: (json['severity'] ?? 'sedang').toString(),
        amount: (json['amount'] as num?)?.toDouble(),
      );
}

/// Baris hitung fisik satu produk.
class SidakCountRow {
  final String productId;
  final String name;
  final String unit;
  final double stockSystem;
  final double costPrice;
  final double basePrice;
  final bool isService;

  double physical;

  SidakCountRow({
    required this.productId,
    required this.name,
    required this.unit,
    required this.stockSystem,
    required this.costPrice,
    required this.basePrice,
    required this.isService,
    double? physical,
  }) : physical = physical ?? stockSystem;

  double get diff => physical - stockSystem;
  double get diffValue => diff * costPrice;
  bool get isChecked => !isService;
}

class SidakSession {
  final String id;
  final DateTime createdAt;
  final String kind;
  final double openingCash;
  final double expectedCash;
  final double actualCash;
  final double cashDiff;
  final double cashSales;
  final double nonCashSales;
  final double stockValueSystem;
  final double stockValuePhysical;
  final double stockDiffValue;
  final int stockChecked;
  final int stockDiffCount;
  final List<SidakFinding> findings;

  const SidakSession({
    required this.id,
    required this.createdAt,
    required this.kind,
    required this.openingCash,
    required this.expectedCash,
    required this.actualCash,
    required this.cashDiff,
    required this.cashSales,
    required this.nonCashSales,
    required this.stockValueSystem,
    required this.stockValuePhysical,
    required this.stockDiffValue,
    required this.stockChecked,
    required this.stockDiffCount,
    required this.findings,
  });

  factory SidakSession.fromJson(Map<String, dynamic> json) {
    final rawFindings = json['findings'];
    final findings = <SidakFinding>[];
    if (rawFindings is List) {
      for (final f in rawFindings) {
        if (f is Map) {
          findings.add(SidakFinding.fromJson(f.cast<String, dynamic>()));
        }
      }
    }
    double num_(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return SidakSession(
      id: (json['id'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      kind: (json['kind'] ?? 'lengkap').toString(),
      openingCash: num_('opening_cash'),
      expectedCash: num_('expected_cash'),
      actualCash: num_('actual_cash'),
      cashDiff: num_('cash_diff'),
      cashSales: num_('cash_sales'),
      nonCashSales: num_('non_cash_sales'),
      stockValueSystem: num_('stock_value_system'),
      stockValuePhysical: num_('stock_value_physical'),
      stockDiffValue: num_('stock_diff_value'),
      stockChecked: (json['stock_checked'] as num?)?.toInt() ?? 0,
      stockDiffCount: (json['stock_diff_count'] as num?)?.toInt() ?? 0,
      findings: findings,
    );
  }

  bool get isClean => cashDiff == 0 && stockDiffValue == 0;
}

/// Service Sidak Bos: audit stok fisik & kas laci.
class SidakService {
  SidakService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Produk yang stoknya bisa dihitung fisik (bukan layanan).
  Future<List<SidakCountRow>> loadCountRows(String outletId) async {
    final res = await _client
        .from('products')
        .select(
            'id, name, unit, stock, cost_price, base_price, is_service, min_stock_alert')
        .eq('outlet_id', outletId)
        .order('name');
    return (res as List).map((raw) {
      final json = (raw as Map).cast<String, dynamic>();
      return SidakCountRow(
        productId: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        unit: (json['unit'] ?? 'pcs').toString(),
        stockSystem: (json['stock'] as num?)?.toDouble() ?? 0,
        costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0,
        basePrice: (json['base_price'] as num?)?.toDouble() ?? 0,
        isService: json['is_service'] == true,
      );
    }).toList();
  }

  /// Ringkasan penjualan tunai/non-tunai periode (dihitung server).
  Future<Map<String, dynamic>> cashSummary(
    String outletId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final res = await _client.rpc('sidak_cash_summary', params: {
      'p_outlet': outletId,
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
    });
    if (res is Map) return res.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// Produk yang terjual dalam [days] hari terakhir (untuk deteksi stok
  /// sistem 0 padahal masih laku).
  Future<Set<String>> soldProductIds(
    String outletId, {
    int days = 7,
  }) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final res = await _client
        .from('stock_logs')
        .select('product_id, change, reason, created_at')
        .eq('outlet_id', outletId)
        .gte('created_at', since.toUtc().toIso8601String())
        .limit(2000);
    final ids = <String>{};
    for (final raw in (res as List)) {
      final json = (raw as Map).cast<String, dynamic>();
      final pid = json['product_id']?.toString();
      if (pid == null || pid.isEmpty) continue;
      final change = (json['change'] as num?)?.toDouble() ?? 0;
      final reason = (json['reason'] ?? '').toString();
      if (reason == 'penjualan' && change < 0) ids.add(pid);
    }
    return ids;
  }

  /// Deteksi otomatis masalah stok/harga (tanpa perlu hitung fisik).
  Future<List<SidakFinding>> autoFindings(
    String outletId, {
    required List<SidakCountRow> rows,
  }) async {
    final findings = <SidakFinding>[];
    final sold = await soldProductIds(outletId);

    for (final r in rows) {
      if (r.isService) continue;
      if (r.stockSystem < 0) {
        findings.add(SidakFinding(
          code: 'stok_minus',
          title: 'Stok minus: ${r.name}',
          detail:
              'Stok sistem ${_qty(r.stockSystem)} ${r.unit}. Catat koreksi stok.',
          severity: 'tinggi',
          amount: r.stockSystem.abs() * r.costPrice,
        ));
      }
      if (r.costPrice <= 0) {
        findings.add(SidakFinding(
          code: 'tanpa_hpp',
          title: 'HPP belum diisi: ${r.name}',
          detail: 'Laba produk ini tidak bisa dihitung tanpa harga modal.',
          severity: 'rendah',
        ));
      } else if (r.basePrice > 0 && r.basePrice < r.costPrice) {
        findings.add(SidakFinding(
          code: 'harga_bawah_hpp',
          title: 'Harga jual di bawah modal: ${r.name}',
          detail:
              'Jual ${_rupiah(r.basePrice)} < modal ${_rupiah(r.costPrice)}. Rugi ${_rupiah(r.costPrice - r.basePrice)} per ${r.unit}.',
          severity: 'tinggi',
          amount: r.costPrice - r.basePrice,
        ));
      }
      if (r.basePrice <= 0) {
        findings.add(SidakFinding(
          code: 'harga_nol',
          title: 'Harga jual belum diisi: ${r.name}',
          detail: 'Produk ini akan tercatat omzet Rp 0 saat terjual.',
          severity: 'sedang',
        ));
      }
      if (r.stockSystem <= 0 && sold.contains(r.productId)) {
        findings.add(SidakFinding(
          code: 'jual_tanpa_stok',
          title: 'Laku tapi stok kosong: ${r.name}',
          detail:
              'Ada penjualan 7 hari terakhir, tapi stok sistem ${_qty(r.stockSystem)}. Cek pencatatan stok.',
          severity: 'tinggi',
        ));
      }
    }
    return findings;
  }

  /// Temuan dari hasil hitung fisik + kas aktual.
  List<SidakFinding> manualFindings({
    required List<SidakCountRow> rows,
    required double cashDiff,
    required bool cashChecked,
  }) {
    final findings = <SidakFinding>[];
    if (cashChecked && cashDiff != 0) {
      findings.add(SidakFinding(
        code: 'kas_selisih',
        title: cashDiff < 0 ? 'Uang laci kurang' : 'Uang laci lebih',
        detail:
            'Selisih ${_rupiah(cashDiff.abs())} dari kas seharusnya. Periksa setoran/kembalian.',
        severity: cashDiff.abs() >= 50000 ? 'tinggi' : 'sedang',
        amount: cashDiff,
      ));
    }
    for (final r in rows) {
      if (r.isService || r.diff == 0) continue;
      findings.add(SidakFinding(
        code: 'stok_selisih',
        title: 'Selisih stok: ${r.name}',
        detail:
            'Sistem ${_qty(r.stockSystem)} ${r.unit}, fisik ${_qty(r.physical)} ${r.unit} '
            '(${r.diff > 0 ? '+' : ''}${_qty(r.diff)}).',
        severity: r.diffValue.abs() >= 50000 ? 'tinggi' : 'sedang',
        amount: r.diffValue,
      ));
    }
    return findings;
  }

  /// Simpan sesi sidak + baris selisih. Mengembalikan id sesi.
  Future<String?> saveSession({
    required String outletId,
    required DateTime from,
    required DateTime to,
    required double openingCash,
    required double expectedCash,
    double? actualCash,
    required double cashDiff,
    required double cashSales,
    required double nonCashSales,
    required List<SidakCountRow> rows,
    required List<SidakFinding> findings,
    String? note,
    String? createdBy,
  }) async {
    final counted = rows.where((r) => !r.isService).toList();
    final diffRows = counted.where((r) => r.diff != 0).toList();
    final systemValue = counted.fold<double>(
        0, (sum, r) => sum + r.stockSystem * r.costPrice);
    final physicalValue = counted.fold<double>(
        0, (sum, r) => sum + r.physical * r.costPrice);
    final diffValue = physicalValue - systemValue;

    final payload = {
      'outlet_id': outletId,
      'kind': 'lengkap',
      'status': 'selesai',
      'period_from': from.toUtc().toIso8601String(),
      'period_to': to.toUtc().toIso8601String(),
      'opening_cash': openingCash,
      'expected_cash': expectedCash,
      'actual_cash': actualCash,
      'cash_diff': cashDiff,
      'cash_sales': cashSales,
      'non_cash_sales': nonCashSales,
      'stock_value_system': systemValue,
      'stock_value_physical': physicalValue,
      'stock_diff_value': diffValue,
      'stock_checked': counted.length,
      'stock_diff_count': diffRows.length,
      'findings': findings.map((f) => f.toJson()).toList(),
      'note': note,
      'created_by': createdBy,
    };

    final res = await _client
        .from('sidak_sessions')
        .insert(payload)
        .select('id')
        .maybeSingle();
    final sessionId = res?['id']?.toString();
    if (sessionId == null) return null;

    if (diffRows.isNotEmpty) {
      await _client.from('sidak_items').insert([
        for (final r in diffRows)
          {
            'session_id': sessionId,
            'outlet_id': outletId,
            'product_id': r.productId.isEmpty ? null : r.productId,
            'product_name': r.name,
            'unit': r.unit,
            'stock_system': r.stockSystem,
            'stock_physical': r.physical,
            'diff': r.diff,
            'cost_price': r.costPrice,
            'diff_value': r.diffValue,
          },
      ]);
    }
    return sessionId;
  }

  /// Catat sesi ke jejak aksi Dokter Bisnis (untuk evaluasi & teguran).
  Future<void> logAction(String sessionId) async {
    try {
      await _client.rpc('sidak_log_action', params: {'p_session': sessionId});
    } catch (_) {
      // Jejak aksi bersifat pelengkap; jangan gagalkan simpan sidak.
    }
  }

  Future<List<SidakSession>> listSessions(
    String outletId, {
    int limit = 10,
  }) async {
    final res = await _client
        .from('sidak_sessions')
        .select()
        .eq('outlet_id', outletId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (res as List)
        .map((raw) =>
            SidakSession.fromJson((raw as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<Map<String, dynamic>>> sessionItems(String sessionId) async {
    final res = await _client
        .from('sidak_items')
        .select()
        .eq('session_id', sessionId)
        .order('diff', ascending: true);
    return (res as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static String _qty(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  static String _rupiah(double v) {
    final neg = v < 0;
    final s = v.abs().round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${neg ? '-' : ''}Rp $buf';
  }
}
