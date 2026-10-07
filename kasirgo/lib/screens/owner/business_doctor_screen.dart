import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/business_doctor_service.dart';
import '../../widgets/common/business_doctor/doctor_blocks.dart';
import '../../widgets/common/centennial_background.dart';
import '../../widgets/common/supporter_gate.dart';
import '../modules/supporter_screen.dart';
import 'doctor_intake_screen.dart';
import 'doctor_promotion_log_screen.dart';
import 'product_list_screen.dart';
import 'report_screen.dart';
import 'whatsapp_broadcast_screen.dart';

class BusinessDoctorScreen extends ConsumerStatefulWidget {
  const BusinessDoctorScreen({super.key, this.service});

  final BusinessDoctorService? service;

  @override
  ConsumerState<BusinessDoctorScreen> createState() =>
      _BusinessDoctorScreenState();
}

class _Msg {
  final String role;
  final String text;
  final List blocks;

  _Msg(this.role, this.text, this.blocks);
}

class _BusinessDoctorScreenState extends ConsumerState<BusinessDoctorScreen> {
  static const _actions = <({IconData icon, String label, String prompt})>[
    (
      icon: Icons.assignment_rounded,
      label: 'Diagnosa Usaha',
      prompt: 'Mulai diagnosa usaha saya.',
    ),
    (
      icon: Icons.trending_down_rounded,
      label: 'Kenapa Omzet Turun?',
      prompt: 'Kenapa omzet saya turun belakangan ini?',
    ),
    (
      icon: Icons.campaign_rounded,
      label: 'Saran Promosi',
      prompt: 'Beri saya ide promosi murah yang cepat menambah pembeli.',
    ),
    (
      icon: Icons.inventory_2_rounded,
      label: 'Cek Stok & Kas',
      prompt: 'Cek stok barang dan arus kas usaha saya.',
    ),
  ];

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Msg>[];

  bool _loading = false;
  String? _conversationId;
  String? _disclaimer;
  String _phase = 'A';
  int _escalationLevel = 0;
  String _caseStatus = 'aktif';

  @override
  void initState() {
    super.initState();
    _loadPhase();
  }

  Future<void> _loadPhase() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    try {
      final phase =
          await (widget.service ?? BusinessDoctorService()).getPhase(outletId);
      if (mounted) setState(() => _phase = phase);
    } catch (_) {}
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final message = text.trim();
    if (message.isEmpty || _loading) return;
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) {
      _snack('Outlet tidak ditemukan.');
      return;
    }
    setState(() {
      _messages.add(_Msg('user', message, const []));
      _loading = true;
    });
    _input.clear();
    _scrollDown();
    try {
      final res = await (widget.service ?? BusinessDoctorService()).chat(
        outletId: outletId,
        message: message,
        conversationId: _conversationId,
      );
      final convId = res['conversation_id']?.toString();
      if (convId != null && convId.isNotEmpty) _conversationId = convId;
      final blocks = (res['blocks'] as List?) ?? const [];
      final reply = res['reply']?.toString() ?? '';
      final disclaimer = res['disclaimer']?.toString();
      final escLevel = int.tryParse(res['escalation_level']?.toString() ?? '') ?? 0;
      final caseStatus = res['status']?.toString() ?? 'aktif';
      if (!mounted) return;
      setState(() {
        if (disclaimer != null && disclaimer.isNotEmpty) {
          _disclaimer = disclaimer;
        }
        _escalationLevel = escLevel;
        _caseStatus = caseStatus;
        _messages.add(_Msg('assistant', reply, blocks));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_Msg(
          'assistant',
          e.toString().replaceFirst('Exception: ', ''),
          const [],
        ));
        _loading = false;
      });
    }
    _scrollDown();
  }

  Future<void> _openIntake() async {
    final summary = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorIntakeScreen(service: widget.service),
      ),
    );
    if (summary != null && summary.isNotEmpty) {
      await _send(summary);
      _loadPhase();
    }
  }

  void _handleAction(String actionKey, String label) {
    if (actionKey == 'upgrade') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SupporterScreen()),
      );
      return;
    }
    if (actionKey == 'catat_promosi') {
      _openPromotionLog();
      return;
    }
    final screen = _actionScreen(actionKey);
    if (screen != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );
      return;
    }
    _send(label);
  }

  Future<void> _openPromotionLog() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const DoctorPromotionLogScreen()),
    );
    if (saved == true) {
      await _send(
          'Saya sudah mencatat hasil promosi. Tolong evaluasi ROI-nya dan tentukan langkah selanjutnya.');
    }
  }

  Widget? _actionScreen(String actionKey) {
    switch (actionKey) {
      case 'wa_marketing':
        return const SupporterFeatureGate(
          featureKey: 'wa_marketing',
          title: 'WA Marketing',
          child: WhatsappBroadcastScreen(),
        );
      case 'sidak_bos':
      case 'progress_tracker':
        return const ReportScreen();
      case 'dynamic_pricing':
      case 'bundling':
      case 'cross_sell':
        return const ProductListScreen();
      default:
        return null;
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AppTheme.durationMedium,
        curve: AppTheme.curveDefault,
      );
    });
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Text('Dokter Bisnis',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                gradient: AppTheme.aiBadgeGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'AI',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: CentennialBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppTheme.formMaxWidth),
            child: Column(
              children: [
                Expanded(child: _buildList()),
                _buildInput(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      children: [
        if (_escalationLevel > 0) ...[
          _buildEscalationBanner(),
          const SizedBox(height: 12),
        ],
        if (_messages.isEmpty) _buildWelcome(),
        for (final msg in _messages) ...[
          const SizedBox(height: 12),
          _buildBubble(msg),
        ],
        if (_loading) ...[
          const SizedBox(height: 12),
          _buildLoading(),
        ],
        if (_disclaimer != null && _messages.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _disclaimer!,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildEscalationBanner() {
    final bandel = _caseStatus == 'kasus_bandel' || _escalationLevel >= 3;
    final color = bandel ? AppTheme.errorColor : AppTheme.warningColor;
    final title = bandel
        ? 'Kasus Bandel'
        : (_escalationLevel >= 2 ? 'Lini Kedua' : 'Evaluasi Ulang');
    final body = bandel
        ? 'Kasus ini sudah berulang kali belum membaik. Sebaiknya minta bantuan pendamping/komunitas.'
        : 'Resep sebelumnya belum berhasil. Dokter sedang mencari akar masalah dan pendekatan baru.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(bandel ? Icons.report_gmailerrorred_rounded : Icons.refresh_rounded,
              color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, color: color)),
                const SizedBox(height: 2),
                Text(body,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: AppTheme.shadowSoft,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  gradient: AppTheme.aiBadgeGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.medical_services_rounded,
                    color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Halo, saya Dokter Bisnis AI',
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'Tanya apa saja soal omzet, stok, promosi, atau arus kas '
                      'usaha Anda.',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_phase == 'A') ...[
          _buildIntakeCta(),
          const SizedBox(height: 16),
        ],
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            for (final a in _actions)
              _buildBigAction(a.icon, a.label, () => _send(a.prompt)),
          ],
        ),
      ],
    );
  }

  Widget _buildIntakeCta() {
    return Material(
      color: AppTheme.primaryColor.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        onTap: _openIntake,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: const Icon(Icons.fact_check_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cek Fisik Toko',
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'Diagnosa lebih akurat dengan 3 langkah singkat.',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBigAction(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Icon(icon, size: 20, color: AppTheme.primaryColor),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(_Msg msg) {
    final isUser = msg.role == 'user';
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          child: Text(
            msg.text,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.4,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            gradient: AppTheme.aiBadgeGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.medical_services_rounded,
              size: 16, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: msg.blocks.isEmpty
                ? Text(
                    msg.text.isEmpty ? 'Maaf, tidak ada jawaban.' : msg.text,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.45,
                      color: AppTheme.textPrimary,
                    ),
                  )
                : DoctorBlocks(
                    blocks: msg.blocks,
                    onChoice: _send,
                    onAction: _handleAction,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            gradient: AppTheme.aiBadgeGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.medical_services_rounded,
              size: 16, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text('Dokter sedang menganalisa...',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: _loading ? null : _send,
                decoration: const InputDecoration(
                  hintText: 'Tulis pertanyaan bisnis Anda...',
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: AppTheme.touchTargetMedium,
              height: AppTheme.touchTargetMedium,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    onTap: _loading ? null : () => _send(_input.text),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
