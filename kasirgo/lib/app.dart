import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'config/app_theme.dart';
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
import 'screens/admin/admin_home_screen.dart';
import 'screens/cashier/cashier_home_screen.dart';
import 'screens/cashier/cashier_pos_screen.dart';
import 'screens/customer/customer_menu_screen.dart';
import 'services/local_db_service.dart';
import 'services/sync_service.dart';
import 'services/auth_service.dart';
import 'providers/auth_provider.dart';

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
      builder: (context, state) => const OwnerHomeScreen(),
    ),
    GoRoute(
      path: '/owner/products',
      builder: (context, state) => const ProductListScreen(),
    ),
    GoRoute(
      path: '/owner/products/add',
      builder: (context, state) => const ProductFormScreen(),
    ),
    GoRoute(
      path: '/owner/pos',
      builder: (context, state) => const PosScreen(),
    ),
    GoRoute(
      path: '/owner/reports',
      builder: (context, state) => const ReportScreen(),
    ),
    GoRoute(
      path: '/owner/customers',
      builder: (context, state) => const CustomerListScreen(),
    ),
    GoRoute(
      path: '/owner/employees',
      builder: (context, state) => const EmployeeScreen(),
    ),
    GoRoute(
      path: '/owner/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminHomeScreen(),
    ),
    GoRoute(
      path: '/admin/reports',
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Laporan Admin')),
      ),
    ),
    GoRoute(
      path: '/cashier',
      builder: (context, state) => const CashierHomeScreen(),
    ),
    GoRoute(
      path: '/cashier/pos',
      builder: (context, state) => const CashierPosScreen(),
    ),
    GoRoute(
      path: '/customer',
      builder: (context, state) => const CustomerMenuScreen(),
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KasirGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}