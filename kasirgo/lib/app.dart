import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'config/app_theme.dart';
import 'config/supabase_config.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/owner/owner_home_screen.dart';
import 'screens/owner/product_form_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/cashier/cashier_home_screen.dart';
import 'screens/customer/customer_menu_screen.dart';

class KasirGoApp extends StatelessWidget {
  const KasirGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KasirGo',
      theme: AppTheme.theme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  redirect: _authGuard,
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
      builder: (context, state) => const OwnerHomeScreen(tabIndex: 0),
      routes: [
        GoRoute(
          path: 'products',
          builder: (context, state) => const OwnerHomeScreen(tabIndex: 0),
          routes: [
            GoRoute(
              path: 'add',
              builder: (context, state) => const ProductFormScreen(),
            ),
            GoRoute(
              path: 'edit/:id',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return ProductFormScreen(productId: id);
              },
            ),
          ],
        ),
        GoRoute(
          path: 'pos',
          builder: (context, state) => const OwnerHomeScreen(tabIndex: 1),
        ),
        GoRoute(
          path: 'reports',
          builder: (context, state) => const OwnerHomeScreen(tabIndex: 2),
        ),
        GoRoute(
          path: 'customers',
          builder: (context, state) => const OwnerHomeScreen(tabIndex: 3),
        ),
        GoRoute(
          path: 'employees',
          builder: (context, state) => const OwnerHomeScreen(tabIndex: 4),
        ),
        GoRoute(
          path: 'settings',
          builder: (context, state) => const OwnerHomeScreen(tabIndex: 5),
        ),
      ],
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminHomeScreen(),
    ),
    GoRoute(
      path: '/cashier',
      builder: (context, state) => const CashierHomeScreen(),
    ),
    GoRoute(
      path: '/customer-menu',
      builder: (context, state) => const CustomerMenuScreen(),
    ),
  ],
);

String? _authGuard(BuildContext context, GoRouterState state) {
  final isAuthenticated = supabase.auth.currentUser != null;
  final isAuthRoute = state.matchedLocation == '/login' ||
      state.matchedLocation == '/register' ||
      state.matchedLocation == '/customer-menu';

  if (!isAuthenticated && !isAuthRoute) {
    return '/login';
  }

  if (isAuthenticated && isAuthRoute) {
    final role = _getUserRole();
    return _roleBasedRedirect(role);
  }

  return null;
}

String _roleBasedRedirect(String? role) {
  switch (role) {
    case 'owner':
      return '/owner';
    case 'admin':
      return '/admin';
    case 'cashier':
      return '/cashier';
    default:
      return '/owner';
  }
}

String? _getUserRole() {
  final user = supabase.auth.currentUser;
  if (user == null) return null;
  final role = user.userMetadata?['role'] ?? user.appMetadata['role'];
  return role?.toString();
}