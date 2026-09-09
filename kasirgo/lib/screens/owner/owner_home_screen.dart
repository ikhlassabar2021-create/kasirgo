import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'product_list_screen.dart';
import 'pos_screen.dart';
import 'report_screen.dart';
import 'customer_list_screen.dart';
import 'employee_screen.dart';
import 'settings_screen.dart';

class OwnerHomeScreen extends ConsumerStatefulWidget {
  final int tabIndex;
  const OwnerHomeScreen({super.key, this.tabIndex = 0});

  @override
  ConsumerState<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends ConsumerState<OwnerHomeScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.tabIndex;
  }

  @override
  void didUpdateWidget(OwnerHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabIndex != oldWidget.tabIndex) {
      _currentIndex = widget.tabIndex;
    }
  }

  void _onTabTapped(int index) {
    switch (index) {
      case 0:
        context.go('/owner/products');
        break;
      case 1:
        context.go('/owner/pos');
        break;
      case 2:
        context.go('/owner/reports');
        break;
      case 3:
        context.go('/owner/customers');
        break;
      case 4:
        context.go('/owner/employees');
        break;
      case 5:
        context.go('/owner/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF1E1B4B),
          selectedItemColor: const Color(0xFF06B6D4),
          unselectedItemColor: Colors.white.withOpacity(0.5),
          selectedLabelStyle: TextStyle(fontSize: 12),
          unselectedLabelStyle: TextStyle(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: 'Produk',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale_outlined),
              activeIcon: Icon(Icons.point_of_sale),
              label: 'Kasir',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Laporan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outlined),
              activeIcon: Icon(Icons.people),
              label: 'Pelanggan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.badge_outlined),
              activeIcon: Icon(Icons.badge),
              label: 'Karyawan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Setting',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const ProductListScreen();
      case 1:
        return const PosScreen();
      case 2:
        return const ReportScreen();
      case 3:
        return const CustomerListScreen();
      case 4:
        return const EmployeeScreen();
      case 5:
        return const SettingsScreen();
      default:
        return const ProductListScreen();
    }
  }
}