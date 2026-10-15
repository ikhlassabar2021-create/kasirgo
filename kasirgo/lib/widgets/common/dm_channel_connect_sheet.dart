import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../services/dm_service.dart';

/// Bottom sheet self-service untuk owner menghubungkan akun kanal
/// (media sosial / iklan) sendiri TANPA superadmin.
///
/// - Token hanya dikirim ke server (tidak pernah dibaca kembali).
/// - Posting manual selalu bisa; koneksi akun dipakai untuk melacak status
///   dan (bila tersedia) posting otomatis.
class DmChannelConnectSheet extends StatefulWidget {
  const DmChannelConnectSheet({
    super.key,
    required this.outletId,
    required this.channels,
    required this.service,
    this.initialStatus = const [],
    this.title = 'Hubungkan Akun Kanal',
  });

  final String outletId;

  /// Peta kode kanal -> label tampilan.
  final Map<String, String> channels;
  final DmService service;
  final List<Map<String, dynamic>> initialStatus;
  final String title;

  @override
  State<DmChannelConnectSheet> createState() => _DmChannelConnectSheetState();
}

class _DmChannelConnectSheetState extends State<DmChannelConnectSheet> {
  late List<Map<String, dynamic>> _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _status = List<Map<String, dynamic>>.from(widget.initialStatus);
    _refresh();
    _checkRedirectResult();
  }

  /// Bila aplikasi dimuat ulang setelah callback OAuth (redirect balik membawa
  /// `?dm_oauth=connected|error`), tampilkan hasilnya lalu segarkan status.
  void _checkRedirectResult() {
    final params = Uri.base.queryParameters;
    final result = params['dm_oauth'];
    if (result == null || result.isEmpty) return;
    final channel = params['channel'] ?? '';
    final label = widget.channels[channel] ?? channel;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (result == 'connected') {
        final acct = params['account'];
        _snack('Akun $label berhasil dihubungkan${(acct != null && acct.isNotEmpty) ? ' ($acct)' : ''}.');
      } else {
        _snack('Koneksi $label gagal: ${params['message'] ?? 'silakan coba lagi'}');
      }
      _refresh();
    });
  }

  bool _isConnected(String channel) => _status.any(
      (c) => c['channel'] == channel && c['is_connected'] == true);

  String? _accountName(String channel) {
    for (final c in _status) {
      if (c['channel'] == channel && c['is_connected'] == true) {
        final n = c['account_name']?.toString();
        if (n != null && n.isNotEmpty) return n;
      }
    }
    return null;
  }

  Future<void> _refresh() async {
    try {
      final res = await widget.service.getChannelStatus(widget.outletId);
      if (!mounted) return;
      setState(() => _status = res);
    } catch (_) {}
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _connect(String channel) async {
    final supportsOauth = widget.service.supportsOauth(channel);
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChannelFormSheet(
        channel: channel,
        label: widget.channels[channel] ?? channel,
        currentName: _accountName(channel),
        isConnected: _isConnected(channel),
        supportsOauth: supportsOauth,
      ),
    );
    if (result == null) return;
    if (result['action'] == 'oauth') {
      await _startOauth(channel);
      return;
    }
    setState(() => _busy = true);
    try {
      if (result['action'] == 'disconnect') {
        await widget.service
            .disconnectChannelAccount(widget.outletId, channel);
        _snack('Akun ${widget.channels[channel]} diputuskan.');
      } else {
        await widget.service.connectChannelAccount(
          outletId: widget.outletId,
          channel: channel,
          accountName: result['account_name'],
          externalId: result['external_id'],
          token: result['token'],
        );
        _snack('Akun ${widget.channels[channel]} berhasil dihubungkan.');
      }
      await _refresh();
    } catch (e) {
      _snack('Gagal: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Koneksi otomatis: buka halaman login resmi platform (OAuth), lalu tunggu
  /// sampai akun muncul terhubung. Bila superadmin belum mengonfigurasi app
  /// OAuth, tampilkan pesan agar owner memakai form manual.
  Future<void> _startOauth(String channel) async {
    setState(() => _busy = true);
    try {
      final redirect =
          '${Uri.base.origin}${Uri.base.path}';
      final res = await widget.service.startOauthConnect(
        outletId: widget.outletId,
        channel: channel,
        redirectTo: redirect,
      );
      final url = res['auth_url']?.toString() ?? '';
      if (res['configured'] != true || url.isEmpty) {
        _snack(res['message']?.toString() ??
            'Koneksi otomatis belum tersedia. Silakan pakai form manual.');
        return;
      }
      final ok = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (!ok) {
        _snack('Tidak bisa membuka halaman login platform.');
        return;
      }
      _snack('Silakan login di halaman yang terbuka. Menunggu koneksi...');
      await _pollUntilConnected(channel);
    } catch (e) {
      _snack('Gagal: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pollUntilConnected(String channel) async {
    for (var i = 0; i < 40; i++) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      try {
        final res = await widget.service.getChannelStatus(widget.outletId);
        if (!mounted) return;
        setState(() => _status = res);
        if (_isConnected(channel)) {
          _snack('Akun ${widget.channels[channel]} berhasil dihubungkan.');
          return;
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected =
        widget.channels.keys.where(_isConnected).length;
    final total = widget.channels.length;
    final maxH = MediaQuery.of(context).size.height * 0.86;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
            child: Row(
              children: [
                Icon(Icons.hub_rounded, color: AppTheme.primaryColor, size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.title,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Tutup',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _pill('$connected terhubung', AppTheme.successColor),
                const SizedBox(width: 8),
                _pill('${total - connected} belum', AppTheme.textSecondary),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                _buildGuideCard(),
                const SizedBox(height: 12),
                ...widget.channels.entries.map(_buildChannelTile),
                const SizedBox(height: 12),
                Text(
                  'Catatan: KasirGo TIDAK menyimpan password akun Anda. '
                  'Token (bila diisi) hanya dipakai server untuk menghubungkan akun dan tidak bisa dilihat lagi.',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildGuideCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_rounded,
                  color: AppTheme.warningColor, size: 18),
              const SizedBox(width: 6),
              Text('Cara pakai (mudah)',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          _guideStep('1', 'Ketuk kanal yang ingin dihubungkan.'),
          _guideStep('2',
              'Pilih "Hubungkan Otomatis" (login ke platform) - cara termudah & aman.'),
          _guideStep('3',
              'Atau isi manual: nama akun (+ username/ID & token bila punya).'),
          _guideStep('4',
              'Selesai - Anda bisa langsung posting manual.'),
          const SizedBox(height: 4),
          Text(
            'Posting manual (salin caption + buka WhatsApp/Website) selalu bisa '
            'meski akun belum dihubungkan.',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _guideStep(String n, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(n,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelTile(MapEntry<String, String> e) {
    final isConnected = _isConnected(e.key);
    final name = _accountName(e.key);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: isConnected
              ? AppTheme.successColor.withValues(alpha: 0.5)
              : AppTheme.borderColor,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: _busy ? null : () => _connect(e.key),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  isConnected
                      ? Icons.check_circle_rounded
                      : Icons.link_off_rounded,
                  color: isConnected
                      ? AppTheme.successColor
                      : AppTheme.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.value,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                      Text(
                        isConnected
                            ? 'Terhubung${name != null ? ' - $name' : ''}'
                            : 'Belum dihubungkan',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: isConnected
                                ? AppTheme.successColor
                                : AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isConnected
                      ? Icons.settings_rounded
                      : Icons.add_circle_outline_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelFormSheet extends StatefulWidget {
  const _ChannelFormSheet({
    required this.channel,
    required this.label,
    this.currentName,
    required this.isConnected,
    this.supportsOauth = false,
  });

  final String channel;
  final String label;
  final String? currentName;
  final bool isConnected;
  final bool supportsOauth;

  @override
  State<_ChannelFormSheet> createState() => _ChannelFormSheetState();
}

class _ChannelFormSheetState extends State<_ChannelFormSheet> {
  late final TextEditingController _name;
  final TextEditingController _external = TextEditingController();
  final TextEditingController _token = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.currentName ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _external.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(widget.label,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Tutup',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (widget.supportsOauth) ...[
                  SizedBox(
                    width: double.infinity,
                    height: AppTheme.touchTargetMedium,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(
                          context, <String, String>{'action': 'oauth'}),
                      icon: const Icon(Icons.login_rounded, size: 20),
                      label: Text('Hubungkan Otomatis (Login ${widget.label})',
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Disarankan: login langsung ke platform. Akun langsung '
                    'terhubung dan lebih aman (tanpa menempel token).',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppTheme.borderColor)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('atau isi manual',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppTheme.textSecondary)),
                      ),
                      const Expanded(child: Divider(color: AppTheme.borderColor)),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: _dec('Nama akun', 'Contoh: Toko Berkah Jaya',
                      Icons.storefront_rounded),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _external,
                  textInputAction: TextInputAction.next,
                  decoration: _dec('Username / ID akun (opsional)',
                      'Contoh: @toko_berkah', Icons.alternate_email_rounded),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _token,
                  obscureText: _obscure,
                  decoration: _dec(
                    'Token akses (opsional)',
                    'Tempel token dari platform (bila ada)',
                    Icons.key_rounded,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tidak punya token? Biarkan kosong. Akun tetap bisa ditandai '
                  'terhubung untuk pencatatan, dan Anda tetap bisa posting manual.',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: AppTheme.touchTargetMedium,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, <String, String>{
                            'action': 'save',
                            'account_name': _name.text.trim(),
                            'external_id': _external.text.trim(),
                            'token': _token.text.trim(),
                          }),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(color: AppTheme.primaryColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium),
                            ),
                          ),
                          child: Text('Hubungkan',
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.isConnected) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: AppTheme.touchTargetMedium,
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(
                          context, <String, String>{'action': 'disconnect'}),
                      icon: const Icon(Icons.link_off_rounded,
                          color: AppTheme.errorColor),
                      label: Text('Putuskan akun',
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.errorColor)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: AppTheme.surfaceMutedColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        borderSide: const BorderSide(color: AppTheme.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        borderSide: const BorderSide(color: AppTheme.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
    );
  }
}
