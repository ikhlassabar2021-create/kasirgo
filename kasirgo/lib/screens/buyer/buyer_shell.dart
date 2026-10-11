import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../models/app_customer.dart';
import '../../models/order.dart';
import '../../providers/app_mode_provider.dart';
import '../../services/order_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/centennial_background.dart';
import '../../widgets/common/responsive.dart';
import 'buyer_home_tab.dart';
import 'buyer_onboarding_screen.dart';

/// ST17-4 (Phase 17 - Ekosistem Hyper-Local): shell Pembeli.
///
/// Menampilkan onboarding zero-friction bila profil belum ada, lalu shell
/// dengan tab Beranda / Pesanan / Profil. Radar + katalog diisi pada ST17-5.
class BuyerShell extends ConsumerStatefulWidget {
  const BuyerShell({super.key});

  @override
  ConsumerState<BuyerShell> createState() => _BuyerShellState();
}

class _BuyerShellState extends ConsumerState<BuyerShell> {
  int _index = 0;

  static const _navItems = [
    AppNavItem(icon: Icons.storefront_rounded, label: 'Beranda'),
    AppNavItem(icon: Icons.receipt_long_rounded, label: 'Pesanan'),
    AppNavItem(icon: Icons.person_rounded, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(appCustomerProvider);

    return customerAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const BuyerOnboardingScreen(),
      data: (customer) {
        if (customer == null) return const BuyerOnboardingScreen();
        return AppShell(
          headerTitle: _titles[_index],
          navItems: _navItems,
          currentIndex: _index,
          onIndexChanged: (i) => setState(() => _index = i),
          mobileTitle: Text(
            _titles[_index],
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          brand: _BrandMark(),
          drawer: _buildDrawer(customer),
          sidebarFooter: _buildSidebarFooter(customer),
          body: IndexedStack(
            index: _index,
            children: [
              BuyerHomeTab(customer: customer),
              const BuyerOrdersTab(),
              BuyerProfileView(customer: customer, standalone: false),
            ],
          ),
        );
      },
    );
  }

  static const _titles = ['KasirGo Pembeli', 'Pesanan Saya', 'Profil Saya'];

  Widget _buildDrawer(AppCustomer customer) {
    return Drawer(
      backgroundColor: AppTheme.surfaceColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const _BrandMark(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      customer.displayName,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.borderColor),
            for (var i = 0; i < _navItems.length; i++)
              ListTile(
                leading: Icon(
                  _navItems[i].icon,
                  color: _index == i ? AppTheme.primaryColor : AppTheme.textSecondary,
                ),
                title: Text(
                  _navItems[i].label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: _index == i ? FontWeight.w700 : FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                onTap: () {
                  setState(() => _index = i);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarFooter(AppCustomer customer) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: AppButton(
        label: 'Ganti Mode',
        icon: Icons.swap_horiz_rounded,
        variant: AppButtonVariant.outline,
        onPressed: () => _switchMode(context, ref),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 32,
          width: 32,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 8),
        Text(
          'KasirGo',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

Future<void> _switchMode(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Ganti Mode?'),
      content: const Text('Anda akan kembali ke pemilihan mode Penjual / Pembeli.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Ganti Mode'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await ref.read(appCustomerServiceProvider).signOut();
  await ref.read(appModeProvider.notifier).clear();
  ref.invalidate(appCustomerProvider);
  if (context.mounted) context.go('/mode');
}

/// Tab Pesanan: daftar pesanan milik Pembeli saat ini.
class BuyerOrdersTab extends ConsumerStatefulWidget {
  const BuyerOrdersTab({super.key});

  @override
  ConsumerState<BuyerOrdersTab> createState() => _BuyerOrdersTabState();
}

class _BuyerOrdersTabState extends ConsumerState<BuyerOrdersTab> {
  final _service = OrderService();
  List<Order> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orders = await _service.myOrders();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_orders.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 60),
          Center(
            child: Column(
              children: [
                const Icon(Icons.receipt_long_rounded,
                    size: 48, color: AppTheme.textSecondary),
                const SizedBox(height: 12),
                Text(
                  'Belum ada pesanan',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pesananmu akan muncul di sini.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _OrderCard(order: _orders[i]),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.code ?? 'Pesanan',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order.statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${order.isDelivery ? 'Diantar' : 'Ambil sendiri'}'
            '${order.createdAt != null ? ' - ${Formatters.date(order.createdAt!)}' : ''}',
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Total',
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const Spacer(),
              Text(
                Formatters.currency(order.total),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Layar/isi Profil Pembeli: info akun, ganti mode, keluar.
class BuyerProfileView extends ConsumerWidget {
  final AppCustomer customer;
  final bool standalone;

  const BuyerProfileView({
    super.key,
    required this.customer,
    this.standalone = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.displayName,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.phone ?? 'Belum ada nomor',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppCard(
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.verified_user_rounded,
                label: 'Mode',
                value: 'Pembeli',
              ),
              const Divider(height: 24, color: AppTheme.borderColor),
              _InfoRow(
                icon: Icons.lock_rounded,
                label: 'Sesi',
                value: 'Anonim aman',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Ganti Mode',
          icon: Icons.swap_horiz_rounded,
          variant: AppButtonVariant.outline,
          onPressed: () => _switchMode(context, ref),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'Keluar',
          icon: Icons.logout_rounded,
          variant: AppButtonVariant.danger,
          onPressed: () => _signOut(context, ref),
        ),
        const SizedBox(height: 24),
        Text(
          'Data Anda hanya dipakai untuk memproses pesanan pada warung tujuan.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary),
        ),
      ],
    );

    if (!standalone) {
      return CentennialBackground(child: content);
    }
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Profil Saya'),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      body: CentennialBackground(child: content),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar?'),
        content: const Text('Sesi Pembeli Anda akan diakhiri.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(appCustomerServiceProvider).signOut();
    await ref.read(appModeProvider.notifier).clear();
    ref.invalidate(appCustomerProvider);
    if (context.mounted) context.go('/mode');
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
