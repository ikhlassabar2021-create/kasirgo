import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/settlement_service.dart';
import '../../services/supporter_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/supporter_gate.dart';
import '../../screens/auth/onboarding_kyc_screen.dart';
import '../../utils/formatters.dart';
import '../../utils/qris_config.dart';
import 'report_schedule_screen.dart';
import 'guide_screen.dart';
import 'multi_outlet_screen.dart';
import '../../utils/receipt_generator.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoading = true;
  DateTime? _supporterEndDate;
  Entitlements? _entitlements;
  Map<String, dynamic> _billingConfig = SupporterService.fallbackBilling;
  bool _autoRenew = true;
  Map<String, dynamic>? _outletData;
  Map<String, dynamic>? _kycData;
  int? _staffQuotaCurrent;
  int? _staffQuotaMax;
  String? _kycStatus;
  Map<String, dynamic>? _financialConfig;

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
        final settlementService = SettlementService();

        // Load outlet data
        final outletRes = await client
            .from('outlets')
            .select()
            .eq('id', outletId)
            .maybeSingle();
        _outletData = outletRes;

        // Load supporter data
        final supRes = await client
            .from('supporters')
            .select()
            .eq('outlet_id', outletId)
            .eq('status', 'active')
            .order('start_date', ascending: false)
            .limit(1)
            .maybeSingle();

        if (supRes != null) {
          _autoRenew = supRes['auto_renew'] == true;
          if (supRes['end_date'] != null) {
            _supporterEndDate = DateTime.tryParse(supRes['end_date'] as String);
          }
        } else {
          _supporterEndDate = null;
        }

        // Entitlements + harga Program Pendukung (Control Plane, cache+fallback).
        final supporterService = SupporterService();
        _billingConfig = await supporterService.getBillingConfig();
        _entitlements = await supporterService.getEntitlements(outletId);

        // Load KYC data
        final kycRes = await client
            .from('outlet_kyc')
            .select('*')
            .eq('outlet_id', outletId.toString())
            .maybeSingle();
        
        if (kycRes != null) {
          _kycData = kycRes;
          _kycStatus = kycRes['status'] as String?;
        } else {
          _kycStatus = 'unsubmitted';
        }

        // Load staff quota
        final quotaRes = await client
            .from('outlet_staff_quota')
            .select('*')
            .eq('outlet_id', outletId.toString())
            .maybeSingle();
        
        if (quotaRes != null) {
          _staffQuotaMax = quotaRes['max_staff'] as int? ?? 5;
          _staffQuotaCurrent = quotaRes['current_staff_count'] as int? ?? 0;
        }

        // Load financial config
        _financialConfig = await settlementService.getFinancialConfig(int.parse(outletId.toString()));
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSupport() async {
    final user = ref.read(currentUserProvider);
    final outletId = user?.outletId;
    if (outletId == null || outletId.isEmpty) return;

    final price =
        (_billingConfig['supporter_price'] as num?)?.toDouble() ?? 50000;
    final isActive = _entitlements?.hasAccess ?? false;

    final confirmed = await _confirmSupportDialog(price, isActive);
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final result = await SupporterService()
          .checkout(outletId: outletId, amount: price);
      if (!mounted) return;
      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memproses dukungan: ${result.error ?? "-"}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Terima kasih! Status Pendukung aktif. Fitur bonus terbuka.'),
            backgroundColor: AppTheme.successColor,
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool?> _confirmSupportDialog(double price, bool isActive) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.favorite, color: AppTheme.secondaryColor),
            SizedBox(width: 8),
            Text('Dukung KasirGo',
                style: TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dukungan Anda menjaga KasirGo tetap 100% Gratis Selamanya untuk seluruh UMKM Indonesia.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
                      const Text('Program',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      const Text('Pendukung KasirGo',
                          style: TextStyle(
                              color: AppTheme.accentColor,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isActive ? 'Nominal Perpanjang' : 'Nominal Kontribusi',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      Text(
                        '${Formatters.currency(price)} / bulan',
                        style: const TextStyle(
                            color: AppTheme.secondaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Pembayaran via QRIS. Bonus: buka fitur kosmetik + bebas iklan sponsor di katalog pelanggan.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Icon(Icons.close_rounded, size: 20),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isActive ? 'Perpanjang Sekarang' : 'Dukung Sekarang'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAutoRenew(bool value) async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    setState(() => _autoRenew = value);
    await SupporterService().setAutoRenew(outletId, value);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan & Program Pendukung'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
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
                        _buildReportScheduleEntry(),
                        const SizedBox(height: 16),
                        _buildMultiOutletEntry(),
                        const SizedBox(height: 16),
                        _buildReceiptEntry(),
                        const SizedBox(height: 16),
                        _buildKYCStatusCard(),
                        const SizedBox(height: 16),
                        _buildStaffQuotaCard(),
                        const SizedBox(height: 16),
                        _buildBusinessProfileCard(user),
                        const SizedBox(height: 16),
                        _buildFinancialConfigCard(),
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
                  color: AppTheme.successColor,
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
          if (_entitlements?.hasAccess == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.secondaryColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite, color: AppTheme.secondaryColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (_entitlements?.isSupporter == true)
                          ? 'Terima kasih! Anda Pendukung KasirGo'
                              '${_supporterEndDate != null ? " s/d ${Formatters.date(_supporterEndDate!)}" : ""}'
                          : 'Masa trial Pendukung aktif - tersisa ${_entitlements?.trialDaysLeft ?? 0} hari',
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
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
    final price =
        (_billingConfig['supporter_price'] as num?)?.toDouble() ?? 50000;
    final ent = _entitlements;
    final hasAccess = ent?.hasAccess ?? false;
    final isSupporter = ent?.isSupporter ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: hasAccess
                ? AppTheme.secondaryColor.withValues(alpha: 0.6)
                : AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.volunteer_activism,
                  color: AppTheme.secondaryColor, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Program Pendukung KasirGo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (isSupporter)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('PENDUKUNG',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                )
              else if (hasAccess)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('TRIAL ${ent?.trialDaysLeft ?? 0} HARI',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warningColor)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Fitur inti tetap 100% Gratis Selamanya. Program Pendukung '
            '(sukarela) membuka fitur bonus & menghilangkan iklan sponsor di '
            'katalog pelanggan Anda.',
            style: TextStyle(
                fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          ...SupporterService.premiumFeatures.map(
            (k) => _buildSupportBenefit(
                SupporterService.featureLabels[k] ?? k),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Satu harga untuk semua',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                Text(
                  '${Formatters.currency(price)} / bulan',
                  style: const TextStyle(
                      color: AppTheme.secondaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _handleSupport,
              icon: const Icon(Icons.favorite_rounded, size: 18),
              label: Text(
                isSupporter ? 'Perpanjang Dukungan' : 'Dukung KasirGo Sekarang',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (isSupporter) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text('Perpanjang otomatis tiap bulan',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                ),
                Switch(
                  value: _autoRenew,
                  activeThumbColor: AppTheme.primaryColor,
                  onChanged: _toggleAutoRenew,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupportBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle,
                color: AppTheme.successColor, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12.5, color: AppTheme.textPrimary, height: 1.35)),
          ),
        ],
      ),
    );
  }

  Widget _buildReportScheduleEntry() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.assessment_outlined,
              color: AppTheme.primaryColor, size: 22),
        ),
        title: const Text(
          'Laporan Otomatis ke Bos',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary),
        ),
        subtitle: const Text(
          'Jadwal harian/mingguan/bulanan, kirim via WhatsApp/email',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing:
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        onTap: () async {
          if (!await requireSupporterFeature(
              context, ref, 'auto_bos_report')) {
            return;
          }
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const ReportScheduleScreen()),
          );
        },
      ),
    );
  }

  /// Struk & Logo (logo kustom = Pendukung; tersimpan LOKAL di perangkat).
  Widget _buildReceiptEntry() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.warningColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.receipt_rounded,
              color: AppTheme.warningColor, size: 22),
        ),
        title: const Text(
          'Struk & Logo Toko',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary),
        ),
        subtitle: const Text(
          'Tagline struk + logo kustom di struk digital',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        onTap: _showReceiptDialog,
      ),
    );
  }

  Future<void> _showReceiptDialog() async {
    final existingLogo = await ReceiptGenerator.loadLogo();
    final existingTagline = await ReceiptGenerator.loadTagline();
    if (!mounted) return;

    final taglineController = TextEditingController(text: existingTagline ?? '');
    String logoBase64 = existingLogo ?? '';
    bool isUploading = false;

    Future<void> pickLogo(StateSetter setDialogState) async {
      try {
        setDialogState(() => isUploading = true);
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 512,
        );
        if (picked == null) {
          setDialogState(() => isUploading = false);
          return;
        }
        final bytes = await picked.readAsBytes();
        setDialogState(() {
          logoBase64 = base64Encode(bytes);
          isUploading = false;
        });
      } catch (_) {
        setDialogState(() => isUploading = false);
      }
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceColor,
            title: const Text('Struk & Logo',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Logo kustom tampil di struk digital (PDF) dan tersimpan '
                      'lokal di perangkat ini.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: logoBase64.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                base64Decode(logoBase64),
                                width: 90,
                                height: 90,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.image_outlined),
                              ),
                            )
                          : Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.borderColor),
                              ),
                              child: const Icon(Icons.image_outlined,
                                  color: AppTheme.textSecondary),
                            ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: isUploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.upload_rounded, size: 18),
                            label: const Text('Pilih Logo'),
                            onPressed: isUploading
                                ? null
                                : () async {
                                    if (!await requireSupporterFeature(
                                        context, ref, 'custom_receipt')) {
                                      return;
                                    }
                                    await pickLogo(setDialogState);
                                  },
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (logoBase64.isNotEmpty)
                          TextButton(
                            onPressed: () =>
                                setDialogState(() => logoBase64 = ''),
                            child: const Text('Hapus Logo',
                                style: TextStyle(color: AppTheme.errorColor)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: taglineController,
                      decoration: const InputDecoration(
                        labelText: 'Tagline Struk (opsional)',
                        hintText: 'Contoh: Terima kasih - Warung Berkah',
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Struk dibagikan dari POS setelah transaksi (tombol STRUK). '
                      'Logo tersimpan hanya di perangkat Anda.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Tutup'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await ReceiptGenerator.saveTagline(
                        taglineController.text.trim());
                    if (logoBase64.isEmpty) {
                      await ReceiptGenerator.deleteLogo();
                    } else {
                      await ReceiptGenerator.saveLogo(logoBase64);
                    }
                  } catch (_) {}
                  if (context.mounted && dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Multi-Outlet (Program Pendukung): kelola cabang dalam 1 akun.
  Widget _buildMultiOutletEntry() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.store_rounded,
              color: AppTheme.accentColor, size: 22),
        ),
        title: const Text(
          'Multi Outlet (Cabang)',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary),
        ),
        subtitle: const Text(
          'Kelola beberapa cabang toko, berpindah outlet aktif',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing:
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MultiOutletScreen()),
        ),
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
          _buildMenuRow(Icons.menu_book_rounded, 'Panduan', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GuideScreen()),
            );
          }),
          _buildMenuRow(Icons.cloud_upload_outlined, 'Tautkan Akun Google', () {
            _showLinkAccountDialog();
          }),
          _buildMenuRow(Icons.person_outline, 'Edit Profil', () {
            final currentUser = ref.read(currentUserProvider);
            _showEditProfileDialog(currentUser);
          }),
          _buildMenuRow(Icons.qr_code_2_rounded, 'QRIS Toko (Manual / Statis)', () {
            _showQrisConfigDialog();
          }),
          _buildMenuRow(Icons.lock_outline, 'Ubah Password', () {
            _showChangePasswordDialog();
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tautkan Akun Google', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tautkan akun Google Anda untuk masuk dengan cepat dan mengamankan data KasirGo.',
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
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Membuka autentikasi Akun Google...')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal menautkan Google: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Masuk dengan Google'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  void _showQrisConfigDialog() async {
    final user = ref.read(currentUserProvider);
    final outletId = user?.outletId;
    if (outletId == null || outletId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Outlet ID tidak ditemukan')),
      );
      return;
    }
    QrisConfig existing = const QrisConfig();
    try {
      existing = await QrisConfig.load(outletId: outletId);
    } catch (_) {}
    try {
      final db = await SupabaseService().getPublicOutletPayment(outletId);
      if (db != null) {
        existing = existing.copyWith(
          merchantName: existing.merchantName.trim().isEmpty
              ? (db['merchant_name']?.toString() ?? '')
              : existing.merchantName,
          bankOrWallet: existing.bankOrWallet.trim().isEmpty
              ? (db['bank_wallet']?.toString() ?? '')
              : existing.bankOrWallet,
          qrisString: existing.qrisString.trim().isEmpty
              ? (db['account_number']?.toString() ?? '')
              : existing.qrisString,
          nmid: existing.nmid.trim().isEmpty
              ? (db['nmid']?.toString() ?? '')
              : existing.nmid,
        );
      }
    } catch (_) {}
    if (!mounted) return;

    final nameController = TextEditingController(text: existing.merchantName);
    final nmidController = TextEditingController(text: existing.nmid);
    final walletController = TextEditingController(text: existing.bankOrWallet);
    final qrisStringController = TextEditingController(text: existing.qrisString);

    // Gambar QRIS statis (base64) — terisi otomatis bila sudah pernah diupload.
    String imageBase64 = existing.imageBase64;
    bool isUploading = false;

    Future<void> pickQrisImage(StateSetter setDialogState) async {
      try {
        setDialogState(() => isUploading = true);
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
          maxWidth: 1200,
        );
        if (picked == null) {
          if (mounted) setDialogState(() => isUploading = false);
          return;
        }
        final bytes = await picked.readAsBytes();
        setDialogState(() {
          imageBase64 = base64Encode(bytes);
          isUploading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setDialogState(() => isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal upload gambar: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }

    Uint8List? decodedImage() {
      if (imageBase64.trim().isEmpty) return null;
      try {
        return base64Decode(imageBase64);
      } catch (_) {
        return null;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceColor,
            title: const Text('QRIS & Pembayaran Toko', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upload foto QRIS statis milik toko Anda. Bank/E-Wallet dan No. Rekening akan ditampilkan ke pelanggan di meja, agar mereka bisa bayar (transfer/QRIS) tanpa antre di kasir.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    // Preview gambar QRIS (otomatis terisi bila sudah ada).
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Column(
                        children: [
                          if (decodedImage() != null)
                            Image.memory(
                              decodedImage()!,
                              height: 200,
                              fit: BoxFit.contain,
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Column(
                                children: [
                                  Icon(Icons.qr_code_2, size: 56, color: AppTheme.textSecondary),
                                  SizedBox(height: 8),
                                  Text(
                                    'Belum ada gambar QRIS',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isUploading ? null : () => pickQrisImage(setDialogState),
                                  icon: isUploading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.upload_file, size: 18),
                                  label: Text(decodedImage() != null ? 'Ganti Gambar' : 'Upload Gambar QRIS'),
                                ),
                              ),
                              if (decodedImage() != null) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Hapus gambar',
                                  onPressed: () => setDialogState(() => imageBase64 = ''),
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Merchant / Toko',
                        prefixIcon: Icon(Icons.store, color: AppTheme.textSecondary),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nmidController,
                      decoration: const InputDecoration(
                        labelText: 'NMID / ID Merchant QRIS (opsional)',
                        prefixIcon: Icon(Icons.badge, color: AppTheme.textSecondary),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: walletController,
                      decoration: const InputDecoration(
                        labelText: 'Bank / E-Wallet',
                        hintText: 'Contoh: BCA a.n. Siti, DANA, OVO',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: AppTheme.textSecondary),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qrisStringController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'No. Rekening / Catatan QRIS',
                        prefixIcon: Icon(Icons.notes, color: AppTheme.textSecondary),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Icon(Icons.close_rounded, size: 20),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final config = QrisConfig(
                    merchantName: nameController.text.trim(),
                    nmid: nmidController.text.trim(),
                    bankOrWallet: walletController.text.trim(),
                    qrisString: qrisStringController.text.trim(),
                    imageBase64: imageBase64,
                  );
                  await QrisConfig.save(outletId: outletId, config: config);
                  final saved = await SupabaseService().saveOutletPayment(
                    outletId: outletId,
                    merchantName: config.merchantName,
                    bankWallet: config.bankOrWallet,
                    accountNumber: config.qrisString,
                    nmid: config.nmid,
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        saved
                            ? 'Info pembayaran disimpan. Pelanggan bisa bayar langsung di meja.'
                            : 'QRIS tersimpan lokal, tetapi gagal simpan info pembayaran ke server. Coba lagi.',
                      ),
                      backgroundColor: saved ? AppTheme.successColor : AppTheme.warningColor,
                    ),
                  );
                },
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditProfileDialog(dynamic user) {
    final nameController = TextEditingController(text: _outletData?['name'] ?? user?.name ?? '');
    final phoneController = TextEditingController(text: _outletData?['phone'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profil Usaha', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Usaha',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Nomor Telepon / WhatsApp',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Icon(Icons.close_rounded, size: 20),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newPhone = phoneController.text.trim();
              final outletId = user?.outletId;
              if (outletId != null && outletId.isNotEmpty) {
                try {
                  await Supabase.instance.client
                      .from('outlets')
                      .update({
                        'name': newName,
                        'phone': newPhone.isEmpty ? null : newPhone,
                      })
                      .eq('id', outletId);
                } catch (_) {}
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profil usaha berhasil diperbarui')),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final passController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Password', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password Baru',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Konfirmasi Password Baru',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Icon(Icons.close_rounded, size: 20),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPass = passController.text;
              final confirmPass = confirmController.text;
              if (newPass.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password minimal 6 karakter')),
                );
                return;
              }
              if (newPass != confirmPass) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Konfirmasi password tidak cocok')),
                );
                return;
              }
              try {
                await Supabase.instance.client.auth.updateUser(
                  UserAttributes(password: newPass),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password berhasil diubah')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal mengubah password: $e')),
                  );
                }
              }
            },
            child: const Text('Simpan'),
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

  Widget _buildKYCStatusCard() {
    if (_kycStatus == null) return const SizedBox();

    bool isVerified = _kycStatus == 'verified';
    bool isRejected = _kycStatus == 'rejected';
    bool isPending = _kycStatus == 'pending_review';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isVerified) {
      statusColor = AppTheme.successColor;
      statusIcon = Icons.verified_rounded;
      statusText = 'Terverifikasi';
    } else if (isRejected) {
      statusColor = AppTheme.errorColor;
      statusIcon = Icons.error_rounded;
      statusText = 'Ditolak - Kirim Ulang';
    } else if (isPending) {
      statusColor = AppTheme.warningColor;
      statusIcon = Icons.hourglass_empty_rounded;
      statusText = 'Sedang Ditinjau';
    } else if (_kycStatus == 'draft') {
      statusColor = AppTheme.accentColor;
      statusIcon = Icons.edit_note_rounded;
      statusText = 'Draf Tersimpan';
    } else {
      statusColor = AppTheme.errorColor;
      statusIcon = Icons.gpp_maybe_rounded;
      statusText = 'Belum Diverifikasi';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.3),
            AppTheme.surfaceColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: 10),
              Text(
                statusText,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _kycData?['reject_reason'] ?? 
            (isPending ? 'Tim kami sedang meninjau dokumen KYC Anda.' : 
             isRejected ? 'Mohon perbaiki dan kirim ulang data verifikasi.' :
             isVerified ? 'Data usaha Anda sudah terverifikasi.' :
             'Lengkapi verifikasi untuk mulai berjualan.'),
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: isVerified
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OnboardingKycScreen(),
                      ),
                    ),
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(isVerified ? 'Sudah Terverifikasi' : 'Lengkapi / Perbarui'),
            style: ElevatedButton.styleFrom(
              backgroundColor: statusColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffQuotaCard() {
    final quotaCurrent = _staffQuotaCurrent ?? 0;
    final quotaMax = _staffQuotaMax ?? 5;
    final quotaRemaining = quotaMax - quotaCurrent;
    final percentage = quotaMax > 0
        ? (quotaCurrent / quotaMax).clamp(0.0, 1.0)
        : 0.0;

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
              Icon(Icons.people_outline, color: AppTheme.primaryColor, size: 22),
              SizedBox(width: 8),
              Text(
                'Kuota Staff',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$quotaCurrent staff aktif dari $quotaMax maksimal',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quotaRemaining > 0 
                          ? '$quotaRemaining slot tersedia' 
                          : 'Quota penuh - Upgrade untuk tambah slot',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: quotaRemaining > 0 
                      ? AppTheme.successColor.withValues(alpha: 0.2)
                      : AppTheme.warningColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  quotaRemaining <= 0 ? 'PENUH' : 'OPEN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: quotaRemaining <= 0 ? AppTheme.warningColor : AppTheme.successColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: percentage,
            minHeight: 8,
            backgroundColor: AppTheme.surfaceMutedColor,
            valueColor: AlwaysStoppedAnimation<Color>(
              quotaRemaining > 0 ? AppTheme.primaryColor : AppTheme.warningColor,
            ),
          ),
          const SizedBox(height: 8),
          if (quotaRemaining <= 0) ...[
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () => _showUpgradeModal(),
                icon: const Icon(Icons.upgrade, size: 18),
                label: const Text('Upgrade Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
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

  void _showUpgradeModal() {
    final price =
        (_billingConfig['supporter_price'] as num?)?.toDouble() ?? 50000;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tambah Slot Staf',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kuota gratis sudah penuh. Buka slot staf tambahan lewat '
              'Program Pendukung KasirGo - satu harga untuk semua fitur bonus.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border:
                    Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Program Pendukung KasirGo',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${Formatters.currency(price)}/bulan',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor)),
                  const SizedBox(height: 4),
                  const Text(
                      'Slot staf tambahan + 13 fitur bonus lainnya.',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _handleSupport();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Dukung & Buka Slot'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialConfigCard() {
    final mdrRate = (_financialConfig?['platform_margin_rate'] as num?)?.toDouble() ?? 0.02;
    final instantFee = (_financialConfig?['instant_withdrawal_fee'] as num?)?.toDouble() ?? 0.005;
    final minWithdrawal = (_financialConfig?['min_withdrawal'] as num?)?.toDouble() ?? 50000;

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
            'Konfigurasi Platform',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.payment, 'MDR Base (QRIS)', '2% per transaksi'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.category, 'Margin Platform', '${(mdrRate * 100).toStringAsFixed(0)}%'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.swap_horiz, 'Tarik Kilat Fee', '${(instantFee * 100).toStringAsFixed(1)}%'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.attach_money, 'Min Withdrawal', Formatters.currency(minWithdrawal)),
          const SizedBox(height: 8),
          const Text(
            'Konfigurasi ini dikelola oleh Superadmin via Control Plane.',
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
