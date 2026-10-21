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

  // ST17-2 (Phase 17): notifikasi pesanan online masuk (owner/kasir).
  static const int orderNotificationId = 78101;
  static const String orderChannelId = 'kasirgo_orders';
  static const String orderChannelName = 'Pesanan Online';

  // Dokter Bisnis 3.0: teguran AI + tugas delegasi yang terlambat.
  static const int delegationNotificationId = 78201;
  static const String delegationChannelId = 'kasirgo_delegations';
  static const String delegationChannelName = 'Tugas & Delegasi';

  static const int doctorNotificationId = 78301;
  static const String doctorChannelId = 'kasirgo_doctor';
  static const String doctorChannelName = 'Dokter Bisnis';

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

  /// ST17-2: tampilkan notifikasi + bunyi saat ada pesanan online baru.
  /// [payload] opsional (mis. `order:<outletId>`).
  Future<void> showOrderNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: orderNotificationId,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            orderChannelId,
            orderChannelName,
            channelDescription: 'Notifikasi pesanan online masuk',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(presentSound: true),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Gagal menampilkan notifikasi pesanan: $e');
    }
  }

  /// Notifikasi tugas delegasi yang mendekati/melewati tenggat.
  /// [id] unik per tugas agar notifikasi tidak saling menimpa.
  Future<void> showDelegationNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            delegationChannelId,
            delegationChannelName,
            channelDescription: 'Pengingat tugas yang didelegasikan owner',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(presentSound: true),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Gagal menampilkan notifikasi tugas: $e');
    }
  }

  /// Notifikasi teguran Dokter Bisnis (pengingat/teguran/teguran keras).
  Future<void> showDoctorNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: doctorNotificationId,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            doctorChannelId,
            doctorChannelName,
            channelDescription: 'Teguran dan pengingat dari Dokter Bisnis AI',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(presentSound: true),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Gagal menampilkan notifikasi Dokter Bisnis: $e');
    }
  }
}
