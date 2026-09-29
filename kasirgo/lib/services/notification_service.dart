import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Pembungkus notifikasi lokal (flutter_local_notifications).
/// - Aman di web (plugin punya implementasi web; tetap dibungkus try/catch).
/// - Dipakai untuk pengingat "Laporan Otomatis ke Bos": saat notifikasi di-tap,
///   [payload] berisi URL/teks laporan yang siap dikirim via WhatsApp.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const int reportNotificationId = 78001;
  static const String reportChannelId = 'kasirgo_report';
  static const String reportChannelName = 'Laporan Otomatis';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  void Function(String? payload)? _onTap;

  bool get isReady => _ready;

  Future<void> initialize({void Function(String? payload)? onTap}) async {
    _onTap = onTap;
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      } catch (_) {
        // fallback ke lokasi default bila data tz tidak memuat zona.
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (resp) {
          _onTap?.call(resp.payload);
        },
      );

      // Minta izin (Android 13+ / iOS).
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      // Tangani notifikasi yang membuka app dari kondisi terminated.
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _onTap?.call(launch?.notificationResponse?.payload);
      }
      _ready = true;
    } catch (e) {
      debugPrint('NotificationService init dilewati: $e');
      _ready = false;
    }
  }

  /// Jadwalkan notifikasi berulang untuk laporan otomatis.
  /// [when] harus di masa depan (waktu lokal).
  Future<void> scheduleReportReminder({
    required String title,
    required String body,
    required DateTime when,
    required String payload,
    DateTimeComponents? repeat,
  }) async {
    if (!_ready) return;
    try {
      final scheduled = tz.TZDateTime.from(when, tz.local);
      await _plugin.zonedSchedule(
        id: reportNotificationId,
        title: title,
        body: body,
        scheduledDate:
            scheduled.isBefore(tz.TZDateTime.now(tz.local))
                ? tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1))
                : scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            reportChannelId,
            reportChannelName,
            channelDescription: 'Pengingat laporan otomatis ke bos',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
        matchDateTimeComponents: repeat,
      );
    } catch (e) {
      debugPrint('Gagal menjadwalkan notifikasi: $e');
    }
  }

  Future<void> cancelReportReminder() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: reportNotificationId);
    } catch (_) {}
  }
}
