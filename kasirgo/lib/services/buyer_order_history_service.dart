import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order.dart';

/// Periode filter riwayat pesanan Pembeli.
enum OrderHistoryPeriod { all, daily, weekly, monthly }

extension OrderHistoryPeriodLabel on OrderHistoryPeriod {
  String get label {
    switch (this) {
      case OrderHistoryPeriod.all:
        return 'Semua';
      case OrderHistoryPeriod.daily:
        return 'Harian';
      case OrderHistoryPeriod.weekly:
        return 'Mingguan';
      case OrderHistoryPeriod.monthly:
        return 'Bulanan';
    }
  }

  /// Awal rentang periode (null = tanpa batas / semua).
  DateTime? startFrom(DateTime now) {
    switch (this) {
      case OrderHistoryPeriod.all:
        return null;
      case OrderHistoryPeriod.daily:
        return DateTime(now.year, now.month, now.day);
      case OrderHistoryPeriod.weekly:
        final today = DateTime(now.year, now.month, now.day);
        return today.subtract(Duration(days: today.weekday - 1));
      case OrderHistoryPeriod.monthly:
        return DateTime(now.year, now.month, 1);
    }
  }
}

/// Item 3: riwayat pesanan Pembeli disimpan LOKAL di HP (snapshot), bukan di
/// server. Saat online, snapshot tetap disinkronkan dari server (`myOrders`)
/// lalu digabung (upsert by id). Mendukung filter periode + hapus per item /
/// per periode. Semua data = teks (JSON) sesuai kebijakan penyimpanan.
class BuyerOrderHistoryService {
  static const _key = 'buyer_order_history_v1';

  /// Muat seluruh snapshot lokal (terbaru lebih dulu).
  Future<List<Order>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final orders = decoded
          .whereType<Map>()
          .map((e) => Order.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _sortDesc(orders);
      return orders;
    } catch (e) {
      debugPrint('BuyerOrderHistoryService.load error: $e');
      return [];
    }
  }

  /// Gabungkan pesanan dari server ke snapshot lokal (upsert by id).
  /// Pesanan lokal yang tidak ada di server tetap dipertahankan.
  Future<List<Order>> mergeFromServer(List<Order> serverOrders) async {
    final local = await load();
    final byId = <String, Order>{for (final o in local) o.id: o};
    for (final o in serverOrders) {
      if (o.id.isEmpty) continue;
      byId[o.id] = o;
    }
    final merged = byId.values.toList();
    _sortDesc(merged);
    await _persist(merged);
    return merged;
  }

  /// Hapus satu pesanan dari snapshot lokal.
  Future<List<Order>> deleteOrder(String id) async {
    final local = await load();
    local.removeWhere((o) => o.id == id);
    await _persist(local);
    return local;
  }

  /// Hapus semua pesanan dalam periode tertentu (kecuali `all` = hapus semua).
  Future<List<Order>> deleteByPeriod(OrderHistoryPeriod period) async {
    final local = await load();
    if (period == OrderHistoryPeriod.all) {
      await clear();
      return [];
    }
    final start = period.startFrom(DateTime.now());
    local.removeWhere((o) {
      final t = o.createdAt;
      if (t == null) return false;
      return !t.isBefore(start!);
    });
    await _persist(local);
    return local;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Saring daftar berdasarkan periode (default: Semua).
  static List<Order> filterByPeriod(
    List<Order> orders,
    OrderHistoryPeriod period,
  ) {
    if (period == OrderHistoryPeriod.all) return orders;
    final start = period.startFrom(DateTime.now());
    return orders.where((o) {
      final t = o.createdAt;
      if (t == null) return false;
      return !t.isBefore(start!);
    }).toList();
  }

  Future<void> _persist(List<Order> orders) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(
      orders.map(_toSnapshot).toList(),
    );
    await prefs.setString(_key, raw);
  }

  static Map<String, dynamic> _toSnapshot(Order o) {
    final map = o.toJson();
    map['order_items'] =
        o.items.map((e) => e.toJson()).toList(growable: false);
    return map;
  }

  static void _sortDesc(List<Order> orders) {
    orders.sort((a, b) {
      final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
  }
}
