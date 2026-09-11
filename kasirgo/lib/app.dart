import 'package:flutter/material.dart';
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

class KasirGoApp extends StatelessWidget {
  const KasirGoApp({super.key});

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