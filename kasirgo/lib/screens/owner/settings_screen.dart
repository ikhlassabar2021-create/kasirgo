import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_drawer.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoading = true;
  String _currentTier = 'free';
  DateTime? _expiryDate;
  Map<String, dynamic>? _outletData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider);
      final outletId = user?.outletId;

      if (outletId != null && outletId.isNotEmpty) {
        final client = Supabase.instance.client;

        final outletRes = await client
            .from('outlets')
            .select()
            .eq('id', outletId)
            .maybeSingle();

        final subRes = await client
            .from('subscriptions')
            .select()
            .eq('outlet_id', outletId)
            .order('start_date', ascending: false)
            .limit(1)
            .maybeSingle();

        _outletData = outletRes;

        String tier = 'free';
        DateTime? expiry;

        if (subRes != null && subRes['tier'] != null) {
          tier = subRes['tier'] as String;
          if (subRes['end_date'] != null) {
            expiry = DateTime.tryParse(subRes['end_date'] as String);
          }
        } else if (outletRes != null && outletRes['subscription_tier'] != null) {
          tier = outletRes['subscription_tier'] as String;
          if (outletRes['subscription_expiry'] != null) {
            expiry = DateTime.tryParse(outletRes['subscription_expiry'] as String);
          }
        }

        if (expiry != null && expiry.isBefore(DateTime.now())) {
          tier = 'free';
        }

        _currentTier = tier;
        _expiryDate = expiry;
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleUpgrade(String targetTier) async {
    final user = ref.read(currentUserProvider);
    final outletId = user?.outletId;
    if (outletId == null || outletId.isEmpty) return;

    final isPro = targetTier == 'pro_50';
    final tierTitle = isPro ? 'Paket Pro (Rp 50.000)' : 'Paket Basic (Rp 25.000)';
    final amount = isPro ? 50000 : 25000;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Konfirmasi Langganan',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aktifkan $tierTitle dengan durasi 30 hari.',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Tagihan', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      Text(
                        Formatters.currency(amount),
                        style: TextStyle(
                          color: isPro ? AppTheme.secondaryColor : AppTheme.accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Durasi', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      const Text('30 Hari', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Metode Pembayaran', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      const Text('Simulasi Instan', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isPro ? AppTheme.secondaryColor : Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Bayar & Aktifkan'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final now = DateTime.now();
    final newEndDate = now.add(const Duration(days: 30));

    try {
      final client = Supabase.instance.client;

      await client.from('outlets').update({
        'subscription_tier': targetTier,
        'subscription_expiry': newEndDate.toIso8601String(),
      }).eq('id', outletId);

      try {
        await client.from('subscriptions').insert({
          'outlet_id': outletId,
          'tier': targetTier,
          'start_date': now.toIso8601String(),
          'end_date': newEndDate.toIso8601String(),
          'payment_method': 'dummy_instant',
          'payment_status': 'paid',
          'amount': amount,
        });
      } catch (_) {
      }

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selamat! $tierTitle berhasil diaktifkan.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal upgrade langganan: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan & Langganan'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      drawer: user != null ? AppDrawer(user: user) : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCurrentTierCard(),
                  const SizedBox(height: 16),
                  _buildTierFeaturesCard(),
                  const SizedBox(height: 16),
                  _buildUpgradeCard(),
                  if (_currentTier == 'free') ...[
                    const SizedBox(height: 16),
                    _buildAdBanner(),
                  ],
                  const SizedBox(height: 16),
                  _buildBusinessProfileCard(user),
                  const SizedBox(height: 16),
                  _buildAccountMenuCard(),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () async {
                        await ref.read(currentUserProvider.notifier).signOut();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: const BorderSide(color: AppTheme.errorColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Keluar dari Akun', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentTierCard() {
    Color cardBg;
    Color borderColor;
    Color badgeColor;
    String tierName;
    IconData tierIcon;

    switch (_currentTier) {
      case 'pro_50':
        cardBg = const Color(0xFF3B185F);
        borderColor = AppTheme.secondaryColor;
        badgeColor = const Color(0xFF8B5CF6);
        tierName = 'Paket Pro 50K';
        tierIcon = Icons.workspace_premium;
        break;
      case 'basic_25':
        cardBg = const Color(0xFF172554);
        borderColor = const Color(0xFF2563EB);
        badgeColor = const Color(0xFF3B82F6);
        tierName = 'Paket Basic 25K';
        tierIcon = Icons.verified;
        break;
      case 'free':
      default:
        cardBg = const Color(0xFF334155);
        borderColor = const Color(0xFF64748B);
        badgeColor = const Color(0xFF94A3B8);
        tierName = 'Paket Free (Gratis)';
        tierIcon = Icons.storefront;
        break;
    }

    String expiryText;
    if (_currentTier == 'free') {
      expiryText = 'Masa Aktif: Selamanya (Limit 500 transaksi & 500 produk)';
    } else if (_expiryDate != null) {
      final daysLeft = _expiryDate!.difference(DateTime.now()).inDays;
      final daysText = daysLeft >= 0 ? ' (Sisa $daysLeft hari)' : ' (Kedaluwarsa)';
      expiryText = 'Berlaku hingga: ${Formatters.date(_expiryDate!)}$daysText';
    } else {
      expiryText = 'Masa Aktif: Aktif';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(tierIcon, color: badgeColor, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    tierName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'AKTIF',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  expiryText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTierFeaturesCard() {
    List<String> features;
    switch (_currentTier) {
      case 'pro_50':
        features = [
          'Semua fitur Paket Basic',
          'Diskon, kupon & flash sale otomatis',
          'WhatsApp Commerce (struk, broadcast & CRM)',
          'Social Commerce Sync (Shopee, Tokopedia)',
          'Order QR meja cafe/resto & katalog online',
          'Analisis kesehatan bisnis & cashflow',
          'Multi-outlet management',
          'Bebas iklan banner & dukungan prioritas 24/7',
        ];
        break;
      case 'basic_25':
        features = [
          'Transaksi & produk UNLIMITED',
          'Scan barcode kamera & cetak label barcode',
          'QRIS otomatis dinamis',
          'Notifikasi stok menipis & kedaluwarsa',
          'Laporan keuangan bank-ready (PDF & Excel)',
          'AI Co-Pilot komprehensif',
          'Bebas iklan banner (Tanpa gangguan)',
        ];
        break;
      case 'free':
      default:
        features = [
          'Maksimal 500 produk & 500 transaksi',
          'Input & kelola produk manual',
          'Kasir POS & QRIS manual statis',
          'AI Co-Pilot (Analisis stok & margin dasar)',
          'Laporan penjualan standar',
          'Absensi karyawan dasar',
          'Terdapat iklan banner sponsor',
        ];
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Fitur Paket Anda Saat Ini',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: Colors.greenAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        f,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildUpgradeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.upgrade, color: AppTheme.accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                _currentTier == 'pro_50' ? 'Kelola Langganan' : 'Pilihan Paket & Upgrade',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_currentTier == 'free') ...[
            _buildUpgradeOptionTile(
              title: 'KasirGo Basic',
              price: 'Rp 25.000 / bln',
              badge: 'Populer',
              badgeColor: Colors.blue.shade600,
              desc: 'Unlimited tx/produk, barcode scanner, QRIS otomatis & bebas iklan',
              btnText: 'Upgrade ke Basic',
              btnColor: Colors.blue.shade600,
              onTap: () => _handleUpgrade('basic_25'),
            ),
            const SizedBox(height: 12),
            _buildUpgradeOptionTile(
              title: 'KasirGo Pro',
              price: 'Rp 50.000 / bln',
              badge: 'Super-App',
              badgeColor: AppTheme.secondaryColor,
              desc: 'WhatsApp Commerce, QR meja, Social commerce sync & multi-outlet',
              btnText: 'Upgrade ke Pro',
              btnColor: AppTheme.secondaryColor,
              onTap: () => _handleUpgrade('pro_50'),
            ),
          ] else if (_currentTier == 'basic_25') ...[
            _buildUpgradeOptionTile(
              title: 'KasirGo Pro',
              price: 'Rp 50.000 / bln',
              badge: 'Rekomendasi',
              badgeColor: AppTheme.secondaryColor,
              desc: 'Tingkatkan ke Pro untuk fitur WhatsApp, QR meja, dan multi-outlet',
              btnText: 'Upgrade ke Pro',
              btnColor: AppTheme.secondaryColor,
              onTap: () => _handleUpgrade('pro_50'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.autorenew, size: 18),
                label: const Text('Perpanjang Paket Basic (+30 Hari)'),
                onPressed: () => _handleUpgrade('basic_25'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blueAccent,
                  side: const BorderSide(color: Colors.blueAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.secondaryColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.star, color: AppTheme.secondaryColor, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Anda sedang menikmati seluruh fitur terlengkap KasirGo Pro.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.autorenew, size: 18),
                label: const Text('Perpanjang Paket Pro (+30 Hari)'),
                onPressed: () => _handleUpgrade('pro_50'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpgradeOptionTile({
    required String title,
    required String price,
    required String badge,
    required Color badgeColor,
    required String desc,
    required String btnText,
    required Color btnColor,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(btnText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade900.withValues(alpha: 0.4),
            Colors.orange.shade800.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade600.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'IKLAN SPONSOR',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Mitra Grosir KasirGo',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_shipping, color: Colors.amberAccent, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kulakan Sembako Diskon s/d 20%',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Khusus warung & toko kelontong mitra KasirGo. Gratis ongkir se-Indonesia.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _handleUpgrade('basic_25'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Hilangkan Iklan (Upgrade)',
                  style: TextStyle(fontSize: 11, color: Colors.blueAccent),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Simulasi promo sponsor grosir mitra KasirGo dibuka!'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Klaim Promo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessProfileCard(dynamic user) {
    final businessName = _outletData?['name'] ?? user?.name ?? user?.email ?? '-';
    final businessType = _outletData?['type'] ?? '-';
    final phone = _outletData?['phone'] ?? '-';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profil Usaha',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.store, 'Nama Usaha', businessName),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.category, 'Tipe Bisnis', businessType),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.phone, 'Telepon', phone),
        ],
      ),
    );
  }

  Widget _buildAccountMenuCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Akun & Bantuan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildMenuRow(Icons.person_outline, 'Edit Profil', () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Edit profil akun')),
            );
          }),
          _buildMenuRow(Icons.lock_outline, 'Ubah Password', () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ubah password akun')),
            );
          }),
          _buildMenuRow(Icons.info_outline, 'Tentang KasirGo v1.0.0', () {
            showAboutDialog(
              context: context,
              applicationName: 'KasirGo',
              applicationVersion: '1.0.0',
              applicationLegalese: 'Aplikasi Kasir UMKM Indonesia Super-App',
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
      ],
    );
  }

  Widget _buildMenuRow(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppTheme.textSecondary, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      onTap: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}
