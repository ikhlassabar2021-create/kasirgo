import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../models/app_customer.dart';
import '../../models/buyer_profile.dart';
import '../../models/order.dart';
import '../../providers/app_mode_provider.dart';
import '../../services/buyer_order_history_service.dart';
import '../../services/order_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/centennial_background.dart';
import '../../widgets/common/responsive.dart';
import 'buyer_auth_screen.dart';
import 'buyer_home_tab.dart';
import 'buyer_onboarding_screen.dart';
import 'buyer_order_tracking_screen.dart';

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
      error: (e, _) => const BuyerAuthScreen(),
      data: (customer) {
        if (customer == null) {
          final hasSession = ref.read(appCustomerServiceProvider).hasSession;
          return hasSession
              ? const BuyerOnboardingScreen()
              : const BuyerAuthScreen();
        }
        return AppShell(
          headerTitle: _titles[_index],
          navItems: _navItems,
          currentIndex: _index,
          onIndexChanged: (i) => setState(() => _index = i),
          mobileTitle: Text(
            _titles[_index],
            style: GoogleFonts.plusJakartaSans(
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
                      style: GoogleFonts.plusJakartaSans(
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
                  style: GoogleFonts.plusJakartaSans(
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
          style: GoogleFonts.plusJakartaSans(
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
  final _history = BuyerOrderHistoryService();
  List<Order> _orders = [];
  bool _loading = true;
  OrderHistoryPeriod _period = OrderHistoryPeriod.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 1) Tampilkan snapshot lokal lebih dulu (offline-first).
    final local = await _history.load();
    if (mounted) {
      setState(() {
        _orders = local;
        _loading = false;
      });
    }
    // 2) Sinkronkan dari server bila online, lalu gabung ke snapshot lokal.
    final server = await _service.myOrders();
    if (!mounted || server.isEmpty) return;
    final merged = await _history.mergeFromServer(server);
    if (!mounted) return;
    setState(() => _orders = merged);
  }

  Future<void> _deleteOrder(Order order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus pesanan?'),
        content: Text(
          'Riwayat ${order.code ?? 'pesanan ini'} akan dihapus dari perangkat ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final updated = await _history.deleteOrder(order.id);
    if (!mounted) return;
    setState(() => _orders = updated);
  }

  Future<void> _deletePeriod() async {
    final period = _period;
    final label = period.label.toLowerCase();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus riwayat $label?'),
        content: Text(
          period == OrderHistoryPeriod.all
              ? 'Seluruh riwayat pesanan akan dihapus dari perangkat ini.'
              : 'Riwayat pesanan periode $label akan dihapus dari perangkat ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final updated = await _history.deleteByPeriod(period);
    if (!mounted) return;
    setState(() => _orders = updated);
  }

  void _openTracking(Order order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BuyerOrderTrackingScreen(orderId: order.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final filtered =
        BuyerOrderHistoryService.filterByPeriod(_orders, _period);
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _OrderCard(
                      order: filtered[i],
                      onTap: () => _openTracking(filtered[i]),
                      onDelete: () => _deleteOrder(filtered[i]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppTheme.surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: OrderHistoryPeriod.values
                    .map((p) => _PeriodChip(
                          label: p.label,
                          selected: _period == p,
                          onTap: () => setState(() => _period = p),
                        ))
                    .toList(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Hapus riwayat periode ini',
            onPressed: _orders.isEmpty ? null : _deletePeriod,
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppTheme.errorColor),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pesananmu akan muncul di sini.',
                style: GoogleFonts.plusJakartaSans(
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
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryColor : AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _OrderCard({required this.order, this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.code ?? 'Pesanan',
                  style: GoogleFonts.plusJakartaSans(
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              if (onDelete != null)
                GestureDetector(
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 20, color: AppTheme.errorColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${order.isDelivery ? 'Diantar' : 'Ambil sendiri'}'
            '${order.createdAt != null ? ' - ${Formatters.date(order.createdAt!)}' : ''}',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Total',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const Spacer(),
              Text(
                Formatters.currency(order.total),
                style: GoogleFonts.plusJakartaSans(
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
    final profileAsync = ref.watch(buyerProfileProvider);
    final profile = profileAsync.valueOrNull;
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.phone ?? 'Belum ada nomor',
                      style: GoogleFonts.plusJakartaSans(
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
                icon: Icons.account_circle_rounded,
                label: 'Nama Akun',
                value: (profile?.accountName.isNotEmpty ?? false)
                    ? profile!.accountName
                    : '-',
              ),
              const Divider(height: 24, color: AppTheme.borderColor),
              _InfoRow(
                icon: Icons.person_outline_rounded,
                label: 'Nama',
                value: (profile?.name.isNotEmpty ?? false) ? profile!.name : '-',
              ),
              const Divider(height: 24, color: AppTheme.borderColor),
              _InfoRow(
                icon: Icons.email_rounded,
                label: 'Email',
                value: (profile?.email.isNotEmpty ?? false) ? profile!.email : '-',
              ),
              const Divider(height: 24, color: AppTheme.borderColor),
              _InfoRow(
                icon: Icons.location_on_rounded,
                label: 'Alamat',
                value: (profile?.address.isNotEmpty ?? false)
                    ? profile!.address
                    : '-',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'Ubah Data Akun',
          icon: Icons.edit_rounded,
          variant: AppButtonVariant.outline,
          onPressed: () => _editProfile(context, ref),
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
          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textSecondary),
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

  Future<void> _editProfile(BuildContext context, WidgetRef ref) async {
    final current = await ref.read(buyerProfileServiceProvider).load() ??
        BuyerProfile(
          name: customer.name ?? '',
          phone: customer.phone ?? '',
        );
    if (!context.mounted) return;
    final saved = await showModalBottomSheet<bool>(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditBuyerProfileSheet(initial: current),
    );
    if (saved == true && context.mounted) {
      ref.invalidate(buyerProfileProvider);
      ref.invalidate(appCustomerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data akun tersimpan.')),
      );
    }
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
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Sheet ubah data akun Pembeli (disimpan LOKAL + sinkron nama/nohp ke server).
class _EditBuyerProfileSheet extends ConsumerStatefulWidget {
  final BuyerProfile initial;

  const _EditBuyerProfileSheet({required this.initial});

  @override
  ConsumerState<_EditBuyerProfileSheet> createState() =>
      _EditBuyerProfileSheetState();
}

class _EditBuyerProfileSheetState
    extends ConsumerState<_EditBuyerProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _accountCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _accountCtrl = TextEditingController(text: widget.initial.accountName);
    _nameCtrl = TextEditingController(text: widget.initial.name);
    _emailCtrl = TextEditingController(text: widget.initial.email);
    _phoneCtrl = TextEditingController(text: widget.initial.phone);
    _addressCtrl = TextEditingController(text: widget.initial.address);
  }

  @override
  void dispose() {
    _accountCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final profile = BuyerProfile(
      accountName: _accountCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
    );
    await ref.read(buyerProfileServiceProvider).save(profile);
    // Sinkron nama/nohp ke baris `app_customers` agar pesanan tetap konsisten.
    await ref.read(appCustomerServiceProvider).updateProfile(
          name: profile.name,
          phone: profile.phone,
        );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ubah Data Akun',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _accountCtrl,
                label: 'Nama Akun',
                hint: 'Mis. budi88',
                prefixIcon: Icons.account_circle_rounded,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama akun wajib diisi'
                    : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _nameCtrl,
                label: 'Nama Lengkap',
                hint: 'Mis. Budi Santoso',
                prefixIcon: Icons.person_rounded,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama wajib diisi'
                    : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _emailCtrl,
                label: 'Email (opsional)',
                hint: 'nama@email.com',
                prefixIcon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                    return 'Format email belum benar';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _phoneCtrl,
                label: 'Nomor HP / WhatsApp',
                hint: '08xxxxxxxxxx',
                prefixIcon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                  if (digits.length < 9) return 'Nomor HP belum benar';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _addressCtrl,
                label: 'Alamat Lengkap',
                hint: 'Jalan, No. rumah, RT/RW, Kelurahan, Kota',
                prefixIcon: Icons.location_on_rounded,
                maxLines: 2,
              ),
              const SizedBox(height: 18),
              AppButton(
                label: 'Simpan',
                icon: Icons.check_rounded,
                isLoading: _busy,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
