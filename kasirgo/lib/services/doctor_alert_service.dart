import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'business_doctor_service.dart';
import 'delegation_service.dart';
import 'notification_service.dart';

/// Notifikasi lokal Dokter Bisnis 3.0 (BAGIAN 13.21B):
/// - Tugas delegasi yang mendekati/melewati tenggat.
/// - Teguran Dokter Bisnis (pengingat halus / teguran / teguran keras).
///
/// Notifikasi hanya dikirim sekali per hari per tugas dan sekali per teguran
/// (anti-spam), memakai penanda di SharedPreferences.
class DoctorAlertService {
  DoctorAlertService({
    DelegationService? delegation,
    BusinessDoctorService? doctor,
  })  : _delegation = delegation ?? DelegationService(),
        _doctor = doctor ?? BusinessDoctorService();

  final DelegationService _delegation;
  final BusinessDoctorService _doctor;

  static const String _seenKey = 'doctor_alert_seen_v1';
  static const int _maxSeen = 200;
  static const int _delegationIdBase = 78210;

  /// Cek tugas terlambat + teguran terbaru lalu tampilkan notifikasi.
  /// [role] 'owner' memantau semua tugas outlet + teguran; staf hanya tugasnya.
  Future<int> checkAndNotify({
    required String outletId,
    String? userId,
    String role = 'owner',
  }) async {
    if (outletId.isEmpty) return 0;
    final prefs = await SharedPreferences.getInstance();
    final seen = (prefs.getStringList(_seenKey) ?? <String>[]).toList();
    final today = _dayKey(DateTime.now());
    var shown = 0;

    bool isNew(String key) => !seen.contains(key);
    void mark(String key) {
      if (!seen.contains(key)) seen.add(key);
    }

    try {
      final isOwner = role == 'owner';
      final items = isOwner
          ? await _delegation.listForOutlet(outletId, onlyOpen: true)
          : await _delegation.listMine();
      final due = items.where((e) => _needsReminder(e)).toList()
        ..sort((a, b) {
          final ad = a.dueAt ?? DateTime(2100);
          final bd = b.dueAt ?? DateTime(2100);
          return ad.compareTo(bd);
        });

      if (isOwner) {
        final overdue = due.where((e) => e.isOverdue).toList();
        if (overdue.isNotEmpty) {
          final key = 'owner:delegation:$today';
          if (isNew(key)) {
            final names = overdue
                .map((e) => e.assignedName.isNotEmpty ? e.assignedName : e.title)
                .take(3)
                .join(', ');
            await NotificationService.instance.showDelegationNotification(
              id: NotificationService.delegationNotificationId,
              title: '${overdue.length} tugas staf terlambat',
              body: 'Belum selesai: $names. Buka papan delegasi untuk menindaklanjuti.',
              payload: 'delegation:$outletId',
            );
            mark(key);
            shown++;
          }
        }
      } else {
        for (final item in due.take(3)) {
          final key = 'task:${item.id}:$today';
          if (!isNew(key)) continue;
          final label = item.isOverdue ? 'Terlambat' : 'Jatuh tempo';
          await NotificationService.instance.showDelegationNotification(
            id: _delegationIdBase + (item.id.hashCode.abs() % 700),
            title: '$label: ${item.title}',
            body: item.isOverdue
                ? 'Tenggat sudah lewat. Segera kerjakan lalu tandai selesai.'
                : 'Tenggat hari ini. Kerjakan tugas dari owner sekarang.',
            payload: 'delegation:${item.id}',
          );
          mark(key);
          shown++;
        }
      }

      if (isOwner) {
        final reprimand = await _doctor.getLatestReprimand(outletId);
        final id = reprimand?['id']?.toString();
        if (id != null && id.isNotEmpty) {
          final key = 'reprimand:$id';
          if (isNew(key)) {
            final title =
                reprimand?['title']?.toString() ?? 'Teguran Dokter Bisnis';
            final content = reprimand?['content']?.toString() ?? '';
            await NotificationService.instance.showDoctorNotification(
              title: title,
              body: content.isEmpty
                  ? 'Buka Dokter Bisnis untuk melihat detail teguran.'
                  : content,
              payload: 'doctor:$outletId',
            );
            mark(key);
            shown++;
          }
        }
      }
    } catch (e) {
      debugPrint('[DoctorAlert] gagal memeriksa pengingat: $e');
      return shown;
    }

    final pruned = seen.length > _maxSeen
        ? seen.sublist(seen.length - _maxSeen)
        : seen;
    await prefs.setStringList(_seenKey, pruned);
    if (shown > 0) {
      debugPrint('[DoctorAlert] $shown pengingat dikirim untuk $outletId');
    }
    return shown;
  }

  bool _needsReminder(DoctorDelegation item) {
    if (item.isClosed) return false;
    final due = item.dueAt;
    if (due == null) return false;
    if (item.isOverdue) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(due.year, due.month, due.day);
    return target.difference(today).inDays == 0;
  }

  String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
