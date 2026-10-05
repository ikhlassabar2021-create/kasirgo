import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/payment_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/centennial_background.dart';

/// Wizard "Hubungkan Midtrans" — zero-custody: Server Key hanya dikirim ke
/// Edge Function dan disimpan terenkripsi di Supabase Vault. Aplikasi tidak
/// pernah menyimpan atau menampilkan kembali Server Key.
class MidtransConnectScreen extends ConsumerStatefulWidget {
  const MidtransConnectScreen({super.key});

  @override
  ConsumerState<MidtransConnectScreen> createState() =>
      _MidtransConnectScreenState();
}

class _MidtransConnectScreenState extends ConsumerState<MidtransConnectScreen> {
  static const _midtransKeysUrl =
      'https://dashboard.midtrans.com/settings/config_info';

  final _merchantController = TextEditingController();
  final _clientKeyController = TextEditingController();
  final _serverKeyController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _isProduction = true;
  bool _hasServerKey = false;
  String _status = 'pending';
  String? _lastTestResult;
  String? _message;
  bool? _messageOk;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _clientKeyController.dispose();
    _serverKeyController.dispose();
    super.dispose();
  }

  String? get _outletId => ref.read(currentUserProvider)?.outletId;

  Future<void> _load() async {
    final outletId = _outletId;
    if (outletId == null || outletId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final cfg = await PaymentService().loadProviderConfig(outletId);
    if (!mounted) return;
    setState(() {
      _merchantController.text = (cfg['merchant_id'] ?? '').toString();
      _clientKeyController.text = (cfg['client_key'] ?? '').toString();
      _hasServerKey = cfg['has_server_key'] == true;
      _isProduction = cfg['is_production'] == true;
      _status = (cfg['status'] ?? 'pending').toString();
      _lastTestResult = cfg['last_test_result']?.toString();
      _loading = false;
    });
  }

  Future<void> _openKeysPage() async {
    final uri = Uri.parse(_midtransKeysUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Tidak bisa membuka browser. Kunjungi dashboard.midtrans.com', false);
    }
  }

  void _showMessage(String text, bool ok) {
    setState(() {
      _message = text;
      _messageOk = ok;
    });
  }

  Future<bool> _save({bool silent = false}) async {
    final outletId = _outletId;
    if (outletId == null || outletId.isEmpty) {
      _showMessage('Outlet tidak ditemukan.', false);
      return false;
    }
    if (_merchantController.text.trim().isEmpty ||
        _clientKeyController.text.trim().isEmpty) {
      _showMessage('Merchant ID dan Client Key wajib diisi.', false);
      return false;
    }
    if (!_hasServerKey && _serverKeyController.text.trim().isEmpty) {
      _showMessage('Server Key wajib diisi.', false);
      return false;
    }
    setState(() => _saving = true);
    try {
      final cfg = await PaymentService().savePaymentConfig(
        outletId: outletId,
        merchantId: _merchantController.text.trim(),
        clientKey: _clientKeyController.text.trim(),
        serverKey: _serverKeyController.text.trim(),
        isProduction: _isProduction,
      );
      if (!mounted) return false;
      setState(() {
        _hasServerKey = cfg['has_server_key'] == true;
        _status = (cfg['status'] ?? 'pending').toString();
        _serverKeyController.clear();
      });
      if (!silent) _showMessage('Kredensial tersimpan. Lanjutkan Tes Koneksi.', true);
      return true;
    } catch (e) {
      if (mounted) _showMessage(e.toString().replaceFirst('Exception: ', ''), false);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    final outletId = _outletId;
    if (outletId == null || outletId.isEmpty) return;
    setState(() => _testing = true);
    try {
      if (!await _save(silent: true)) return;
      final res = await PaymentService().testPaymentConnection(outletId);
      if (!mounted) return;
      final valid = res['valid'] == true;
      setState(() {
        _status = valid ? 'verified' : 'pending';
        _lastTestResult = res['message']?.toString();
      });
      _showMessage(res['message']?.toString() ?? (valid ? 'Kredensial valid.' : 'Kredensial tidak valid.'), valid);
    } catch (e) {
      if (mounted) _showMessage(e.toString().replaceFirst('Exception: ', ''), false);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Hubungkan Midtrans',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: CentennialBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: AppTheme.formMaxWidth),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildStatusCard(),
                      const SizedBox(height: 16),
                      _buildGuideCard(),
                      const SizedBox(height: 16),
                      _buildFormCard(),
                      if (_message != null) ...[
                        const SizedBox(height: 12),
                        _buildMessage(),
                      ],
                      const SizedBox(height: 20),
                      AppButton(
                        label: 'Tes Koneksi',
                        icon: Icons.wifi_tethering_rounded,
                        isLoading: _testing || _saving,
                        onPressed: _testConnection,
                        height: AppTheme.touchTargetLarge,
                      ),
                      const SizedBox(height: 10),
                      AppButton(
                        label: 'Simpan Saja',
                        variant: AppButtonVariant.outline,
                        icon: Icons.save_outlined,
                        isLoading: _saving,
                        onPressed: () => _save(),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final verified = _status == 'verified';
    final color = verified ? AppTheme.successColor : AppTheme.warningColor;
    final label = verified
        ? 'Terhubung'
        : (_status == 'disabled' ? 'Nonaktif' : 'Belum diverifikasi');
    return _card(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Icon(
              verified ? Icons.verified_rounded : Icons.link_off_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: $label',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                if (_lastTestResult != null && _lastTestResult!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(_lastTestResult!,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _isProduction ? 'Mode Produksi' : 'Mode Sandbox',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          if (_hasServerKey)
            const Icon(Icons.lock_rounded,
                size: 18, color: AppTheme.successColor),
        ],
      ),
    );
  }

  Widget _buildGuideCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cara menghubungkan',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _step('1', 'Buka Dashboard Midtrans dan salin kredensial dari menu '
              'Settings > Access Keys.'),
          _step('2', 'Tempel Merchant ID, Client Key, dan Server Key di bawah.'),
          _step('3', 'Tekan Tes Koneksi. Bila valid, QRIS dinamis otomatis aktif.'),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _openKeysPage,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Buka Access Keys Midtrans'),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Server Key disimpan terenkripsi di server KasirGo dan tidak '
                  'pernah disimpan di perangkat.',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _step(String no, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Text(no,
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kredensial',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _merchantController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Merchant ID',
              hintText: 'G123456789',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _clientKeyController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Client Key',
              hintText: 'SB-Mid-client-...',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _serverKeyController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Server Key',
              hintText: _hasServerKey
                  ? 'Sudah tersimpan - isi untuk mengganti'
                  : 'SB-Mid-server-...',
              suffixIcon: _hasServerKey
                  ? const Icon(Icons.check_circle_rounded,
                      color: AppTheme.successColor)
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppTheme.primaryColor,
            value: _isProduction,
            onChanged: (v) => setState(() => _isProduction = v),
            title: Text('Mode Produksi',
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
              _isProduction
                  ? 'Transaksi nyata. Pastikan QRIS sudah diaktifkan di Midtrans.'
                  : 'Uji coba (sandbox). Tidak ada uang nyata.',
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage() {
    final ok = _messageOk == true;
    final color = ok ? AppTheme.successColor : AppTheme.errorColor;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_message!,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: child,
    );
  }
}
