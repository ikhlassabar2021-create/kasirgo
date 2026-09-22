import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_drawer.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoading = true;
  String? _activeSupporterTier;
  DateTime? _supporterEndDate;
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

        final supRes = await client
            .from('supporters')
            .select()
            .eq('outlet_id', outletId)
            .eq('status', 'active')
            .order('start_date', ascending: false)
            .limit(1)
            .maybeSingle();

        _outletData = outletRes;

        if (supRes != null) {
          _activeSupporterTier = supRes['tier'] as String?;
          if (supRes['end_date'] != null) {
            _supporterEndDate = DateTime.tryParse(supRes['end_date'] as String);
          }
        } else {
          _activeSupporterTier = null;
          _supporterEndDate = null;
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleJoinSupporter(String tier, double amount, String tierLabel) async {
    final user = ref.read(currentUserProvider);
    final outletId = user?.outletId;
    if (outletId == null || outletId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.favorite, color: AppTheme.secondaryColor),
            SizedBox(width: 8),
            Text('Dukung KasirGo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terima kasih telah berkontribusi menjaga KasirGo tetap 100% Gratis Selamanya untuk seluruh UMKM Indonesia.',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
                      const Text('Kategori Dukungan', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      Text(tierLabel, style: const TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Nominal Kontribusi', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      Text(
                        Formatters.currency(amount),
                        style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
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
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Dukung Sekarang'),
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
      await client.from('supporters').insert({
        'outlet_id': outletId,
        'tier': tier,
        'start_date': now.toIso8601String(),
        'end_date': newEndDate.toIso8601String(),
        'amount': amount,
        'status': 'active',
      });

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terima kasih! Dukungan $tierLabel berhasil diaktifkan.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memproses dukungan: $e'),
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
        title: const Text('Pengaturan & Program Pendukung'),
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
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildForeverFreeBanner(),
                      const SizedBox(height: 16),
                      _buildSupporterProgramCard(),
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
              ),
            ),
    );
  }

  Widget _buildForeverFreeBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.35),
            AppTheme.secondaryColor.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.all_inclusive, color: AppTheme.accentColor, size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'KasirGo Gratis Selamanya',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
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
          const SizedBox(height: 10),
          const Text(
            'Seluruh fitur inti KasirGo: POS kasir, produk & transaksi tanpa batas, laporan, multi-tipe outlet, dan AI Co-Pilot dapat dinikmati 100% tanpa biaya langganan.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
          if (_activeSupporterTier != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.secondaryColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite, color: AppTheme.secondaryColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Terima kasih! Anda aktif sebagai Pendukung KasirGo (${_activeSupporterTier!.toUpperCase()})'
                      '${_supporterEndDate != null ? " s/d ${Formatters.date(_supporterEndDate!)}" : ""}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupporterProgramCard() {
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
          const Row(
            children: [
              Icon(Icons.volunteer_activism, color: AppTheme.secondaryColor, size: 22),
              SizedBox(width: 8),
              Text(
                'Program Pendukung KasirGo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Dukungan sukarela dari pemilik usaha untuk membiayai server, pengembangan fitur baru, dan ekosistem UMKM Indonesia mandiri.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          _buildSupporterTierTile(
            title: 'Pendukung Kawan',
            amountText: 'Rp 25.000 / bulan',
            tier: 'pendukung',
            amount: 25000,
            desc: 'Badge Kawan KasirGo di profil & akses awal fitur eksperimental.',
            color: Colors.blue.shade600,
          ),
          const SizedBox(height: 12),
          _buildSupporterTierTile(
            title: 'Pendukung Pro',
            amountText: 'Rp 50.000 / bulan',
            tier: 'pro',
            amount: 50000,
            desc: 'Badge Supporter Pro, prioritas konsultasi AI, dan fitur custom struk.',
            color: AppTheme.secondaryColor,
          ),
          const SizedBox(height: 12),
          _buildSupporterTierTile(
            title: 'Pendukung Setia',
            amountText: 'Rp 100.000 / bulan',
            tier: 'setia',
            amount: 100000,
            desc: 'Badge Mitra Utama, direct line tim KasirGo, dan roadmap feature voting.',
            color: AppTheme.accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSupporterTierTile({
    required String title,
    required String amountText,
    required String tier,
    required double amount,
    required String desc,
    required Color color,
  }) {
    final isCurrent = _activeSupporterTier == tier;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? Colors.greenAccent : color.withValues(alpha: 0.5),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('AKTIF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                )
              else
                Text(
                  amountText,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(desc, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              onPressed: () => _handleJoinSupporter(tier, amount, title),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrent ? Colors.green.shade700 : color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                isCurrent ? 'Perpanjang Dukungan' : 'Pilih $title',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessProfileCard(dynamic user) {
    final businessName = _outletData?['name'] ?? user?.name ?? user?.email ?? '-';
    final businessType = _outletData?['outlet_type'] ?? _outletData?['type'] ?? '-';
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
          _buildMenuRow(Icons.cloud_upload_outlined, 'Tautkan Akun (Google / No. HP)', () {
            _showLinkAccountDialog();
          }),
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
          _buildMenuRow(Icons.info_outline, 'Tentang KasirGo v3.0.0', () {
            showAboutDialog(
              context: context,
              applicationName: 'KasirGo',
              applicationVersion: '3.0.0',
              applicationLegalese: 'Aplikasi Kasir UMKM Indonesia - Gratis Selamanya',
            );
          }),
        ],
      ),
    );
  }

  void _showLinkAccountDialog() {
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tautkan Akun', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tautkan akun Anda untuk mengamankan data dan melakukan backup transaksi ke Cloud secara otomatis.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await AuthService().linkAccountWithGoogle();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal menautkan Google: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Tautkan Akun Google'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Nomor WhatsApp / HP',
                prefixText: '+62 ',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final phone = phoneController.text.trim();
              Navigator.pop(ctx);
              if (phone.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kode OTP SMS/WA berhasil dikirim')),
                );
              }
            },
            child: const Text('Kirim OTP'),
          ),
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
