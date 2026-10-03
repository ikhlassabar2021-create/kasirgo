import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'config/app_theme.dart';
import 'models/product.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/owner/owner_home_screen.dart';
import 'screens/owner/product_list_screen.dart';
import 'screens/owner/product_form_screen.dart';
import 'screens/owner/pos_screen.dart';
import 'screens/owner/report_screen.dart';
import 'screens/owner/customer_list_screen.dart';
import 'screens/owner/employee_screen.dart';
import 'screens/owner/settings_screen.dart';
import 'screens/owner/guide_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/cashier/cashier_home_screen.dart';
import 'screens/cashier/cashier_pos_screen.dart';
import 'screens/cashier/cashier_report_screen.dart';
import 'screens/customer/customer_menu_screen.dart';
import 'screens/customer/customer_catalog_screen.dart';
import 'services/local_db_service.dart';
import 'services/sync_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/report_scheduler_service.dart';
import 'providers/auth_provider.dart';
import 'widgets/common/kyc_gate.dart';

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/owner',
      builder: (context, state) => const KycGate(child: OwnerHomeScreen()),
    ),
    GoRoute(
      path: '/owner/products',
      builder: (context, state) => const KycGate(child: ProductListScreen()),
    ),
    GoRoute(
      path: '/owner/products/add',
      builder: (context, state) => KycGate(
        child: OwnerHomeScreen(
          initialIndex: 1,
          subScreen: ProductFormScreen(product: state.extra as Product?),
        ),
      ),
    ),
    GoRoute(
      path: '/owner/pos',
      builder: (context, state) => const KycGate(child: PosScreen()),
    ),
    GoRoute(
      path: '/owner/reports',
      builder: (context, state) => const KycGate(child: ReportScreen()),
    ),
    GoRoute(
      path: '/owner/customers',
      builder: (context, state) => const KycGate(child: CustomerListScreen()),
    ),
    GoRoute(
      path: '/owner/employees',
      builder: (context, state) => const KycGate(child: EmployeeScreen()),
    ),
    GoRoute(
      path: '/owner/settings',
      builder: (context, state) => const KycGate(child: SettingsScreen()),
    ),
    GoRoute(
      path: '/owner/guide',
      builder: (context, state) => const KycGate(child: GuideScreen()),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const KycGate(child: AdminHomeScreen()),
    ),
    GoRoute(
      path: '/admin/reports',
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Laporan Admin')),
      ),
    ),
    GoRoute(
      path: '/cashier',
      builder: (context, state) => const KycGate(child: CashierHomeScreen()),
    ),
    GoRoute(
      path: '/cashier/pos',
      builder: (context, state) => const KycGate(child: CashierPosScreen()),
    ),
    GoRoute(
      path: '/cashier/reports',
      builder: (context, state) => const KycGate(child: CashierReportScreen()),
    ),
    GoRoute(
      path: '/customer',
      builder: (context, state) => CustomerMenuScreen(
        initialOutletId: state.uri.queryParameters['outlet'] ?? '',
        initialTable: state.uri.queryParameters['table'] ?? '',
      ),
    ),
    GoRoute(
      path: '/catalog',
      builder: (context, state) => CustomerCatalogScreen(
        initialOutletId: state.uri.queryParameters['outlet'] ?? '',
      ),
    ),
  ],
);

class KasirGoApp extends ConsumerStatefulWidget {
  const KasirGoApp({super.key});

  @override
  ConsumerState<KasirGoApp> createState() => _KasirGoAppState();
}

class _KasirGoAppState extends ConsumerState<KasirGoApp> {
  @override
  void initState() {
    super.initState();
    _initialize();
    _listenAuth();
  }

  void _listenAuth() {
    final authService = AuthService();
    authService.authStateChanges.listen((data) async {
      if (data.session != null && mounted) {
        final user = await authService.getCurrentUser();
        if (user != null && mounted) {
          ref.read(currentUserProvider.notifier).setUserDirectly(user);
          final route = switch (user.role) {
            'admin' => '/admin',
            'cashier' => '/cashier',
            _ => '/owner',
          };
          _router.go(route);
        }
      }
    });
  }

  Future<void> _initialize() async {
    try {
      final localDb = LocalDatabase();
      await localDb.initialize();

      final syncService = SyncService();
      syncService.startPeriodicSync();
    } catch (_) {
      // Offline engine unavailable (e.g. web preview); app still works online.
    }

    // Notifikasi lokal untuk pengingat "Laporan Otomatis ke Bos".
    NotificationService.instance.initialize(onTap: _handleNotificationTap);

    final authService = AuthService();
    final user = await authService.getCurrentUser();
    if (!mounted || user == null) return;

    ref.read(currentUserProvider.notifier).setUserDirectly(user);
    final route = switch (user.role) {
      'admin' => '/admin',
      'cashier' => '/cashier',
      _ => '/owner',
    };
    _router.go(route);
  }

  Future<void> _handleNotificationTap(String? payload) async {
    if (payload == null || !payload.startsWith('report:')) return;
    final outletId = payload.substring('report:'.length);
    if (outletId.isEmpty) return;
    try {
      final svc = ReportSchedulerService();
      final schedule = await svc.load(outletId);
      if (schedule != null) {
        await svc.sendViaWhatsApp(outletId, schedule);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KasirGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: _router,
    );
  }
}