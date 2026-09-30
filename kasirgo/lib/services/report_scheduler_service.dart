import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/formatters.dart';
import 'notification_service.dart';
import 'supabase_service.dart';

/// Konfigurasi laporan otomatis ke bos.
class ReportSchedule {
  final String? id;
  final bool enabled;
  final String period; // daily | weekly | monthly
  final String sendTime; // HH:mm
  final int? dayOfWeek; // 1=Senin .. 7=Minggu (untuk weekly)
  final int? dayOfMonth; // 1..28 (untuk monthly)
  final List<String> recipients; // maks 3 (nomor WA / email)
  final List<String> channels; // wa | email
  final Map<String, dynamic> contentFlags;
  final DateTime? lastSentAt;

  const ReportSchedule({
    this.id,
    this.enabled = false,
    this.period = 'daily',
    this.sendTime = '21:00',
    this.dayOfWeek,
    this.dayOfMonth,
    this.recipients = const [],
    this.channels = const ['wa'],
    this.contentFlags = const {
      'omzet': true,
      'transaksi': true,
      'rata_rata': true,
      'produk_terlaris': true,
      'laba': true,
    },
    this.lastSentAt,
  });

  ReportSchedule copyWith({
    String? id,
    bool? enabled,
    String? period,
    String? sendTime,
    int? dayOfWeek,
    int? dayOfMonth,
    List<String>? recipients,
    List<String>? channels,
    Map<String, dynamic>? contentFlags,
    DateTime? lastSentAt,
  }) {
    return ReportSchedule(
      id: id ?? this.id,
      enabled: enabled ?? this.enabled,
      period: period ?? this.period,
      sendTime: sendTime ?? this.sendTime,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      recipients: recipients ?? this.recipients,
      channels: channels ?? this.channels,
      contentFlags: contentFlags ?? this.contentFlags,
      lastSentAt: lastSentAt ?? this.lastSentAt,
    );
  }

  factory ReportSchedule.fromJson(Map<String, dynamic> json) {
    return ReportSchedule(
      id: json['id']?.toString(),
      enabled: json['enabled'] == true,
      period: (json['period'] ?? 'daily').toString(),
      sendTime: (json['send_time'] ?? '21:00').toString().substring(0, 5),
      dayOfWeek: (json['day_of_week'] as num?)?.toInt(),
      dayOfMonth: (json['day_of_month'] as num?)?.toInt(),
      recipients: ((json['recipients'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      channels: ((json['channels'] as List?) ?? const ['wa'])
          .map((e) => e.toString())
          .toList(),
      contentFlags: (json['content_flags'] is Map)
          ? Map<String, dynamic>.from(json['content_flags'] as Map)
          : const {},
      lastSentAt: json['last_sent_at'] != null
          ? DateTime.tryParse(json['last_sent_at'].toString())
          : null,
    );
  }
}

/// Laporan otomatis ke bos: simpan jadwal, susun teks laporan, bagikan via WA,
/// dan pasang pengingat notifikasi lokal.
class ReportSchedulerService {
  ReportSchedulerService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const int maxRecipients = 3;

  static const Map<String, String> contentLabels = {
    'omzet': 'Total omzet',
    'transaksi': 'Jumlah transaksi',
    'rata_rata': 'Rata-rata per transaksi',
    'produk_terlaris': 'Produk terlaris',
    'laba': 'Estimasi laba',
  };

  Future<ReportSchedule?> load(String outletId) async {
    try {
      final res = await _client
          .from('report_schedules')
          .select()
          .eq('outlet_id', outletId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res == null) return null;
      return ReportSchedule.fromJson(res);
    } catch (_) {
      return null;
    }
  }

  Future<bool> save(String outletId, ReportSchedule s) async {
    final payload = {
      'outlet_id': outletId,
      'period': s.period,
      'send_time': s.sendTime.length >= 5 ? s.sendTime.substring(0, 5) : s.sendTime,
      'day_of_week': s.dayOfWeek,
      'day_of_month': s.dayOfMonth,
      'recipients': s.recipients.take(maxRecipients).toList(),
      'channels': s.channels,
      'content_flags': s.contentFlags,
      'enabled': s.enabled,
    };
    try {
      if (s.id != null && s.id!.isNotEmpty) {
        await _client.from('report_schedules').update(payload).eq('id', s.id!);
      } else {
        await _client.from('report_schedules').insert(payload);
      }
      return true;
    } catch (e) {
      debugPrint('Gagal menyimpan jadwal laporan: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Waktu tayang berikutnya
  // ---------------------------------------------------------------------------

  DateTime? nextRun(ReportSchedule s, {DateTime? from}) {
    if (!s.enabled) return null;
    final now = from ?? DateTime.now();
    final parts = s.sendTime.split(':');
    final hh = int.tryParse(parts.isNotEmpty ? parts[0] : '21') ?? 21;
    final mm = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    if (s.period == 'daily') {
      var run = DateTime(now.year, now.month, now.day, hh, mm);
      if (!run.isAfter(now)) run = run.add(const Duration(days: 1));
      return run;
    }

    if (s.period == 'weekly') {
      final target = (s.dayOfWeek ?? 1).clamp(1, 7); // 1=Senin .. 7=Minggu
      var run = DateTime(now.year, now.month, now.day, hh, mm);
      var diff = target - now.weekday;
      if (diff < 0 || (diff == 0 && !run.isAfter(now))) diff += 7;
      run = run.add(Duration(days: diff));
      return run;
    }

    // monthly
    final dom = (s.dayOfMonth ?? 1).clamp(1, 28);
    var run = DateTime(now.year, now.month, dom, hh, mm);
    if (!run.isAfter(now)) {
      run = DateTime(now.year, now.month + 1, dom, hh, mm);
    }
    return run;
  }

  /// Pasang/ganti pengingat notifikasi lokal sesuai jadwal.
  Future<void> applyLocalReminder(String outletId, ReportSchedule s) async {
    final svc = NotificationService.instance;
    await svc.cancelReportReminder();
    if (!s.enabled) return;
    final next = nextRun(s);
    if (next == null) return;

    DateTimeComponents? repeat;
    if (s.period == 'daily') {
      repeat = DateTimeComponents.time;
    } else if (s.period == 'weekly') {
      repeat = DateTimeComponents.dayOfWeekAndTime;
    } else if (s.period == 'monthly') {
      repeat = DateTimeComponents.dayOfMonthAndTime;
    }

    await svc.scheduleReportReminder(
      title: 'Waktunya kirim laporan ke bos',
      body: 'Ketuk untuk membuka WhatsApp dengan laporan siap kirim.',
      when: next,
      payload: 'report:$outletId',
      repeat: repeat,
    );
  }

  // ---------------------------------------------------------------------------
  // Bangun teks laporan
  // ---------------------------------------------------------------------------

  Future<({DateTime start, DateTime end})> _range(String period) async {
    final now = DateTime.now();
    final end = now;
    DateTime start;
    switch (period) {
      case 'weekly':
        start = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6));
        break;
      case 'monthly':
        start = DateTime(now.year, now.month, 1);
        break;
      default:
        start = DateTime(now.year, now.month, now.day);
    }
    return (start: start, end: end);
  }

  Future<String> buildReportText(
    String outletId,
    ReportSchedule s, {
    String? businessName,
  }) async {
    final range = await _range(s.period);
    final txs = await SupabaseService().getTransactions(
      outletId,
      startDate: range.start,
      endDate: range.end,
      limit: 1000,
    );

    final omzet = txs.fold<double>(0, (sum, t) => sum + t.finalAmount);
    final count = txs.length;
    final avg = count > 0 ? omzet / count : 0.0;

    final flags = s.contentFlags;
    final buf = StringBuffer();
    buf.writeln('*Laporan KasirGo${businessName != null ? " - $businessName" : ""}*');
    buf.writeln('Periode: ${Formatters.date(range.start)} s/d ${Formatters.date(range.end)}');
    buf.writeln('');
    if (flags['omzet'] != false) {
      buf.writeln('Total Omzet: ${Formatters.currency(omzet)}');
    }
    if (flags['transaksi'] != false) {
      buf.writeln('Jumlah Transaksi: $count');
    }
    if (flags['rata_rata'] != false && count > 0) {
      buf.writeln('Rata-rata/Transaksi: ${Formatters.currency(avg)}');
    }

    if (flags['produk_terlaris'] != false && txs.isNotEmpty) {
      final qty = <String, int>{};
      for (final t in txs) {
        for (final it in t.items) {
          qty[it.productName] = (qty[it.productName] ?? 0) + it.quantity;
        }
      }
      final top = qty.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (top.isNotEmpty) {
        buf.writeln('');
        buf.writeln('Produk Terlaris:');
        for (var i = 0; i < top.length && i < 5; i++) {
          buf.writeln('${i + 1}. ${top[i].key} (${top[i].value}x)');
        }
      }
    }

    if (flags['laba'] == true && txs.isNotEmpty) {
      final laba = await _estimateProfit(outletId, txs);
      if (laba != null) {
        buf.writeln('');
        buf.writeln(
            'Estimasi Laba (omzet - HPP): ${Formatters.currency(laba)}');
      }
    }

    // Laba PPOB (transaksi sukses pada periode) - selalu tampil bila ada.
    final ppob = await _ppobSummary(outletId, range.start, range.end);
    if (ppob != null && ppob['sales']! > 0) {
      buf.writeln('');
      buf.writeln('PPOB: jual ${Formatters.currency(ppob['sales']!)}'
          ' - laba ${Formatters.currency(ppob['profit']!)}');
    }

    // Restock B2B (order kulakan pada periode) - tampil bila ada.
    final restock = await _restockSummary(outletId, range.start, range.end);
    if (restock != null && restock['total']! > 0) {
      buf.writeln('');
      buf.writeln('Restock B2B: order ${Formatters.currency(restock['total']!)}'
          ' - komisi ${Formatters.currency(restock['commission']!)}');
    }

    buf.writeln('');
    buf.writeln('Dicatat otomatis oleh KasirGo Super-App UMKM.');
    return buf.toString();
  }

  /// Rekap PPOB periode (status success). Null bila tabel PPOB belum ada.
  Future<Map<String, double>?> _ppobSummary(
      String outletId, DateTime start, DateTime end) async {
    try {
      final res = await _client
          .from('ppob_transactions')
          .select('amount, cost_amount, profit')
          .eq('outlet_id', outletId)
          .eq('status', 'success')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String());
      double sales = 0, profit = 0;
      for (final row in (res as List)) {
        final m = row as Map;
        double d(dynamic v) =>
            v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
        sales += d(m['amount']);
        profit += d(m['profit']);
      }
      return {'sales': sales, 'profit': profit};
    } catch (_) {
      return null;
    }
  }

  /// Rekap restock B2B periode. Null bila tabel belum ada.
  Future<Map<String, double>?> _restockSummary(
      String outletId, DateTime start, DateTime end) async {
    try {
      final res = await _client
          .from('restock_orders')
          .select('amount, commission')
          .eq('outlet_id', outletId)
          .inFilter('status', ['pending', 'confirmed', 'shipped', 'completed'])
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String());
      double total = 0, commission = 0;
      for (final row in (res as List)) {
        final m = row as Map;
        double d(dynamic v) =>
            v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
        total += d(m['amount']);
        commission += d(m['commission']);
      }
      return {'total': total, 'commission': commission};
    } catch (_) {
      return null;
    }
  }

  /// Estimasi laba = omzet - HPP. HPP dihitung dari harga modal produk
  /// (`products.cost_price`) dikali jumlah terjual. Null bila produk belum
  /// punya data modal sama sekali (laporan jujur: tidak menebak).
  Future<double?> _estimateProfit(String outletId, List<dynamic> txs) async {
    double omzet = 0;
    double hpp = 0;
    bool anyCost = false;
    try {
      final prods = await _client
          .from('products')
          .select('id, cost_price')
          .eq('outlet_id', outletId);
      final costById = <String, double>{};
      for (final p in (prods as List)) {
        final c = (p as Map)['cost_price'];
        if (c != null) {
          costById[p['id'].toString()] = (c as num).toDouble();
        }
      }
      for (final t in txs) {
        omzet += t.finalAmount as double;
        for (final it in t.items) {
          final cost = costById[it.productId?.toString() ?? ''];
          if (cost != null) {
            anyCost = true;
            hpp += cost * (it.quantity as num).toDouble();
          }
        }
      }
    } catch (_) {
      return null;
    }
    if (!anyCost) return null;
    return omzet - hpp;
  }

  String _normalizePhone(String raw) {
    var s = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (s.startsWith('+')) s = s.substring(1);
    if (s.startsWith('0')) s = '62${s.substring(1)}';
    return s;
  }

  bool _isEmail(String v) => v.contains('@');

  /// Buka WhatsApp ke penerima pertama dengan teks laporan siap kirim.
  Future<bool> sendViaWhatsApp(
    String outletId,
    ReportSchedule s, {
    String? businessName,
  }) async {
    if (s.recipients.isEmpty) return false;
    final first = s.recipients.firstWhere(
      (r) => !_isEmail(r),
      orElse: () => '',
    );
    if (first.isEmpty) return false;
    final text = await buildReportText(outletId, s, businessName: businessName);
    final uri = Uri.parse(
        'https://wa.me/${_normalizePhone(first)}?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  /// Buka email ke penerima pertama (email) dengan teks laporan.
  Future<bool> sendViaEmail(
    String outletId,
    ReportSchedule s, {
    String? businessName,
  }) async {
    final first = s.recipients.firstWhere((r) => _isEmail(r), orElse: () => '');
    if (first.isEmpty) return false;
    final text = await buildReportText(outletId, s, businessName: businessName);
    final uri = Uri(
      scheme: 'mailto',
      path: first,
      queryParameters: {
        'subject': 'Laporan KasirGo${businessName != null ? " - $businessName" : ""}',
        'body': text,
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }
    return false;
  }
}
