import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/business_doctor_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/business_doctor/doctor_blocks.dart';
import '../../widgets/common/centennial_background.dart';
import '../../widgets/common/supporter_gate.dart';
import '../modules/supporter_screen.dart';
import 'doctor_cases_screen.dart';
import 'doctor_intake_screen.dart';
import 'doctor_promotion_log_screen.dart';
import 'doctor_result_screen.dart';
import 'bundle_manager_screen.dart';
import 'design_studio_screen.dart';
import 'health_score_screen.dart';
import 'multi_outlet_screen.dart';
import 'online_catalog_screen.dart';
import 'pos_screen.dart';
import 'product_list_screen.dart';
import 'qr_table_screen.dart';
import 'recipe_screen.dart';
import 'report_screen.dart';
import 'whatsapp_broadcast_screen.dart';

class BusinessDoctorScreen extends ConsumerStatefulWidget {
  const BusinessDoctorScreen(
      {super.key, this.service, this.conversationId, this.initialMessage});

  final BusinessDoctorService? service;
  final String? conversationId;

  /// Bila diisi, pesan otomatis dikirim saat layar dibuka (mis. rekomendasi
  /// iklan dari Studio Iklan).
  final String? initialMessage;

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
  Map<String, dynamic>? _activePrescription;
  Map<String, dynamic>? _reprimand;
  Map<String, dynamic>? _weeklyReport;
  List<Map<String, dynamic>> _pendingActions = const [];
  Map<String, dynamic>? _identity;
  bool _overduePrompted = false;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _loadPhase();
    _loadPrescription();
    _loadReprimand();
    _loadIdentity();
    _loadWeeklyReport();
    _loadPendingActions();
    if (_conversationId != null) _loadHistory();
    final initial = widget.initialMessage?.trim();
    if (initial != null && initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(initial));
    }
  }

  Future<void> _loadIdentity() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    try {
      final id = await (widget.service ?? BusinessDoctorService())
          .getOutletIdentity(outletId);
      if (!mounted) return;
      setState(() => _identity = id);
    } catch (_) {}
  }

  Future<void> _loadWeeklyReport() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    try {
      final r = await (widget.service ?? BusinessDoctorService())
          .getLatestWeeklyReport(outletId);
      if (!mounted || r == null) return;
      setState(() => _weeklyReport = r);
    } catch (_) {}
  }

  Future<void> _loadPendingActions() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    try {
      final list = await (widget.service ?? BusinessDoctorService())
          .listPendingActions(outletId);
      if (!mounted) return;
      setState(() => _pendingActions = list);
    } catch (_) {}
  }

  Future<void> _decidePending(Map<String, dynamic> action, bool approve) async {
    final id = action['id']?.toString();
    if (id == null || id.isEmpty) return;
    try {
      await (widget.service ?? BusinessDoctorService())
          .decidePendingAction(actionId: id, approve: approve);
      if (!mounted) return;
      setState(() => _pendingActions =
          _pendingActions.where((a) => a['id']?.toString() != id).toList());
      _snack(approve ? 'Aksi disetujui.' : 'Aksi ditolak.');
    } catch (e) {
      _snack('Gagal: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> _loadReprimand() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    try {
      final r = await (widget.service ?? BusinessDoctorService())
          .getLatestReprimand(outletId);
      if (!mounted || r == null) return;
      setState(() => _reprimand = r);
    } catch (_) {}
  }

  Future<void> _loadPrescription() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    try {
      final p = await (widget.service ?? BusinessDoctorService())
          .getActivePrescription(outletId);
      if (!mounted) return;
      setState(() => _activePrescription = p);
      _maybeWarnOverdue();
    } catch (_) {}
  }

  void _maybeWarnOverdue() {
    final p = _activePrescription;
    if (p == null || _overduePrompted) return;
    final due = DateTime.tryParse(p['due_at']?.toString() ?? '');
    if (due == null || !due.isBefore(DateTime.now())) return;
    _overduePrompted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Resep Belum Dijalankan'),
          content: Text(
            'Masa target resep "${p['title'] ?? 'perbaikan'}" sudah lewat. '
            'Ayo jalankan langkahnya sekarang agar omzet membaik.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Nanti'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Lihat Resep'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _loadHistory() async {
    final convId = _conversationId;
    if (convId == null) return;
    setState(() => _loading = true);
    try {
      final rows =
          await (widget.service ?? BusinessDoctorService()).listMessages(convId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(rows.map((r) => _Msg(
                r['role']?.toString() ?? 'assistant',
                r['content']?.toString() ?? '',
                (r['blocks'] as List?) ?? const [],
              )));
        _loading = false;
      });
      _scrollDown();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
      final phase = res['phase']?.toString();
      final prescription = blocks
          .whereType<Map>()
          .map((b) => b.cast<String, dynamic>())
          .where((b) => b['type'] == 'prescription')
          .cast<Map<String, dynamic>?>()
          .firstWhere((b) => true, orElse: () => null);
      final pendingBlock = blocks
          .whereType<Map>()
          .map((b) => b.cast<String, dynamic>())
          .where((b) => b['type'] == 'pending_action')
          .cast<Map<String, dynamic>?>()
          .firstWhere((b) => true, orElse: () => null);
      final identity = (res['identity'] is Map)
          ? (res['identity'] as Map).cast<String, dynamic>()
          : null;
      if (!mounted) return;
      setState(() {
        if (disclaimer != null && disclaimer.isNotEmpty) {
          _disclaimer = disclaimer;
        }
        _escalationLevel = escLevel;
        _caseStatus = caseStatus;
        if (phase != null && phase.isNotEmpty) _phase = phase;
        if (prescription != null) _activePrescription = prescription;
        if (identity != null) _identity = identity;
        _messages.add(_Msg('assistant', reply, blocks));
        _loading = false;
      });
      if (pendingBlock != null) _loadPendingActions();
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

  Future<void> _onPrescriptionStep(
      Map<String, dynamic> block, Map<String, dynamic> step, int index) async {
    final items = ((block['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (index < 0 || index >= items.length) return;
    final key = items[index]['action_key']?.toString() ?? '';
    if (key.isNotEmpty) {
      final hasScreen =
          key == 'upgrade' || key == 'catat_promosi' || _actionScreen(key) != null;
      if (hasScreen) {
        _handleAction(key, items[index]['text']?.toString() ?? '');
      }
    }
    // "Jalankan" membuka fitur DAN menandai langkah sudah dijalankan.
    await _markPrescriptionDone(block, index, true);
  }

  /// Checklist: tandai langkah selesai / batal selesai (tanpa membuka fitur).
  Future<void> _togglePrescriptionStep(
      Map<String, dynamic> block, int index) async {
    final items = ((block['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (index < 0 || index >= items.length) return;
    final done = items[index]['done'] == true;
    await _markPrescriptionDone(block, index, !done);
  }

  Future<void> _markPrescriptionDone(
      Map<String, dynamic> block, int index, bool done) async {
    final items = ((block['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (index < 0 || index >= items.length) return;
    items[index]['done'] = done;
    final updated = {...block, 'items': items};
    final memoryId = block['memory_id']?.toString();
    setState(() {
      _activePrescription = updated;
      // Sinkronkan kartu resep di dalam gelembung chat (bila ada) agar langkah
      // langsung tercoret begitu ditekan "Tandai Selesai"/"Jalankan".
      for (var mi = 0; mi < _messages.length; mi++) {
        final msg = _messages[mi];
        if (msg.blocks.isEmpty) continue;
        var changed = false;
        final newBlocks = <dynamic>[];
        for (final raw in msg.blocks) {
          if (raw is Map && raw['type'] == 'prescription') {
            final sameRef = identical(raw, block);
            final bm = raw['memory_id']?.toString();
            final sameId = memoryId != null &&
                memoryId.isNotEmpty &&
                bm == memoryId;
            if (sameRef || sameId) {
              newBlocks.add(updated);
              changed = true;
              continue;
            }
          }
          newBlocks.add(raw);
        }
        if (changed) {
          _messages[mi] = _Msg(msg.role, msg.text, newBlocks);
        }
      }
    });
    final allDone = items.isNotEmpty && items.every((e) => e['done'] == true);
    try {
      if (memoryId != null && memoryId.isNotEmpty) {
        await (widget.service ?? BusinessDoctorService()).savePrescription(
          memoryId: memoryId,
          block: updated,
          status: allDone ? 'achieved' : null,
        );
      } else {
        await (widget.service ?? BusinessDoctorService())
            .savePrescription(block: updated);
      }
    } catch (_) {}
    if (allDone && mounted) {
      _snack('Semua langkah resep selesai. Mantap!');
    }
  }

  void _openResult() {
    final p = _activePrescription;
    if (p == null) return;
    final items = (p['items'] as List?) ?? const [];
    final steps = items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    DateTime? due;
    final dueRaw = p['due_at']?.toString();
    if (dueRaw != null && dueRaw.isNotEmpty) {
      due = DateTime.tryParse(dueRaw)?.toLocal();
    }
    final days = int.tryParse(p['target_days']?.toString() ?? '');
    final scoreRaw = p['score'] ?? p['health_score'];
    final score = scoreRaw == null ? null : int.tryParse(scoreRaw.toString());
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorResultScreen(
          verdictTitle:
              p['verdict']?.toString() ?? p['title']?.toString() ?? 'Vonis',
          verdictBody: p['verdict_body']?.toString() ?? '',
          score: score,
          scoreHint: p['score_hint']?.toString() ?? '',
          targetDays: days,
          dueDate: due,
          steps: steps,
          onRunStep: (i, step) =>
              _onPrescriptionStep(p, Map<String, dynamic>.from(step), i),
          onToggleStep: (i, step) => _togglePrescriptionStep(p, i),
          onStart: () => Navigator.pop(context),
          onAsk: () {
            Navigator.pop(context);
            _scrollDown();
          },
        ),
      ),
    );
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
        return const ProductListScreen();
      case 'bundling':
        return const SupporterFeatureGate(
          featureKey: 'wa_marketing',
          title: 'Paket Bundling',
          child: BundleManagerScreen(),
        );
      case 'cross_sell':
        // Langkah cross-sell = tawarkan barang tambahan saat pelanggan bayar.
        // Buka POS (di sana muncul chip saran cross-sell), bukan Paket Bundling.
        return const PosScreen();
      case 'referral':
        // CATATAN (owner): fitur Referral dihapus dari UI -> langkah resep
        // dengan aksi referral cukup ditandai selesai (tercoret).
        return null;
      case 'health_score':
        return const SupporterFeatureGate(
          featureKey: 'health_score_pro',
          title: 'Skor Kesehatan Usaha',
          child: HealthScoreScreen(),
        );
      case 'online_catalog':
        return const SupporterFeatureGate(
          featureKey: 'online_catalog',
          title: 'Katalog Online',
          child: OnlineCatalogScreen(),
        );
      case 'qr_table':
        return const SupporterFeatureGate(
          featureKey: 'qr_table',
          title: 'QR Meja',
          child: QrTableScreen(),
        );
      case 'multi_outlet':
        return const SupporterFeatureGate(
          featureKey: 'multi_outlet',
          title: 'Multi Outlet',
          child: MultiOutletScreen(),
        );
      case 'recipe':
        return const RecipeScreen();
      case 'create_asset':
        return const SupporterFeatureGate(
          featureKey: 'digital_marketing',
          title: 'Studio Desain',
          child: DesignStudioScreen(initialTab: 1),
        );
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
        actions: [
          IconButton(
            tooltip: 'Riwayat Kasus',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DoctorCasesScreen(),
              ),
            ),
          ),
        ],
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
        if (_identity != null) ...[
          _buildIdentityCard(),
          const SizedBox(height: 12),
        ],
        if (_weeklyReport != null) ...[
          _buildWeeklyReportCard(),
          const SizedBox(height: 12),
        ],
        if (_pendingActions.isNotEmpty) ...[
          for (final a in _pendingActions) ...[
            _buildPendingActionCard(a),
            const SizedBox(height: 12),
          ],
        ],
        if (_escalationLevel > 0) ...[
          _buildEscalationBanner(),
          const SizedBox(height: 12),
        ],
        if (_reprimand != null) ...[
          _buildReprimandBanner(),
          const SizedBox(height: 12),
        ],
        if (_activePrescription != null) ...[
          DoctorBlocks(
            blocks: [_activePrescription!],
            onPrescription: _onPrescriptionStep,
            onTogglePrescription: _togglePrescriptionStep,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: AppTheme.touchTargetMedium,
            child: AppButton(
              label: 'Lihat Hasil Diagnosa',
              icon: Icons.assignment_outlined,
              variant: AppButtonVariant.outline,
              onPressed: _openResult,
            ),
          ),
          const SizedBox(height: 12),
        ],
        _buildIntakeCta(),
        const SizedBox(height: 12),
        if (_phase != 'A') ...[
          _buildEvaluationCta(),
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

  Widget _buildIdentityCard() {
    final id = _identity!;
    final score = int.tryParse(id['health_score']?.toString() ?? '');
    final disease = id['active_disease']?.toString();
    final phase = id['phase']?.toString() ?? 'A';
    final presc = id['active_prescription']?.toString();
    final age = id['business_age_days']?.toString();
    final scoreColor = score == null
        ? AppTheme.textSecondary
        : (score >= 70
            ? AppTheme.successColor
            : (score >= 40 ? AppTheme.warningColor : AppTheme.errorColor));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_outlined,
                  color: AppTheme.primaryColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kartu Identitas Bisnis',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (score != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Text(
                    'Sehat $score',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: scoreColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _identityChip('Fase $phase'),
              if (disease != null && disease.isNotEmpty)
                _identityChip('Penyakit: $disease', color: AppTheme.warningColor),
              if (presc != null && presc.isNotEmpty)
                _identityChip('Resep: $presc'),
              if (id['deadline'] != null)
                _identityChip(
                    'Tenggat: ${id['deadline'].toString().substring(0, 10)}'),
              if (age != null && age != 'null')
                _identityChip('Usia usaha: $age hari'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _identityChip(String label, {Color? color}) {
    final c = color ?? AppTheme.primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildWeeklyReportCard() {
    final r = _weeklyReport!;
    final data =
        (r['data'] is Map) ? (r['data'] as Map).cast<String, dynamic>() : const {};
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded,
                  color: AppTheme.primaryColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Laporan Mingguan',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Tutup',
                icon: const Icon(Icons.close, size: 18),
                color: AppTheme.textSecondary,
                onPressed: () => setState(() => _weeklyReport = null),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            r['content']?.toString() ?? '',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: AppTheme.textPrimary,
            ),
          ),
          if (data['top_product'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Terlaris: ${data['top_product']}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.successColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingActionCard(Map<String, dynamic> a) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rule_rounded,
                  color: AppTheme.warningColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Perlu Persetujuan Anda',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            a['title']?.toString() ?? '',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          if ((a['body']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              a['body'].toString(),
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.4,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'AI mengusulkan aksi ini tetapi BELUM dijalankan. Anda yang memutuskan.',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Setujui',
                  icon: Icons.check_rounded,
                  onPressed: () => _decidePending(a, true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'Tolak',
                  icon: Icons.close_rounded,
                  variant: AppButtonVariant.outline,
                  onPressed: () => _decidePending(a, false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReprimandBanner() {
    final r = _reprimand!;
    final data = (r['data'] is Map) ? (r['data'] as Map).cast<String, dynamic>() : const {};
    final level = int.tryParse(data['level']?.toString() ?? '') ?? 1;
    final color = level >= 3
        ? AppTheme.errorColor
        : (level == 2 ? AppTheme.warningColor : AppTheme.primaryColor);
    final icon = level >= 3
        ? Icons.gavel
        : (level == 2 ? Icons.notification_important : Icons.notifications_active);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r['title']?.toString() ?? 'Pengingat Dokter Bisnis',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Tandai sudah dibaca',
                icon: const Icon(Icons.close, size: 18),
                color: AppTheme.textSecondary,
                onPressed: () => setState(() => _reprimand = null),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            r['content']?.toString() ?? '',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final reason in const ['Lupa', 'Tidak ada waktu', 'Tidak ada modal', 'Tidak paham'])
                ActionChip(
                  label: Text(
                    reason,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  backgroundColor: AppTheme.surfaceColor,
                  side: BorderSide(color: color.withValues(alpha: 0.5)),
                  onPressed: () {
                    setState(() => _reprimand = null);
                    _send('Dokter, saya belum menjalankan resep karena: $reason. '
                        'Tolong bantu sesuaikan langkahnya agar lebih mudah.');
                  },
                ),
            ],
          ),
        ],
      ),
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

  Widget _buildEvaluationCta() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppTheme.aiBadgeGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: const Icon(Icons.rule_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Evaluasi Resep',
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'Sudah dijalankan? Beri tahu hasilnya, Dokter perbaiki resepnya.',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildEvalButton(
                  'Berhasil',
                  Icons.check_circle_rounded,
                  AppTheme.successColor,
                  'Resep yang saya jalankan berhasil, omzet membaik. Tolong evaluasi dan beri langkah lanjutan.',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildEvalButton(
                  'Belum Berhasil',
                  Icons.refresh_rounded,
                  AppTheme.warningColor,
                  'Resep yang saya jalankan belum berhasil, hasil tidak membaik. Tolong cari akar masalahnya dan perbaiki resepnya.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEvalButton(
      String label, IconData icon, Color color, String prompt) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        onTap: () => _send(prompt),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700, color: color),
                ),
              ),
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
                    onPrescription: _onPrescriptionStep,
                    onTogglePrescription: _togglePrescriptionStep,
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
