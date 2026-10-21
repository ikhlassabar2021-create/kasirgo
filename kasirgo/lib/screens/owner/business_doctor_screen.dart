import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/module_provider.dart';
import '../../providers/outlet_provider.dart';
import '../../services/business_doctor_service.dart';
import '../../services/speech_service.dart';
import '../../services/supabase_service.dart';
import '../../services/voice_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/business_doctor/doctor_blocks.dart';
import '../../widgets/common/centennial_background.dart';
import '../../widgets/common/supporter_gate.dart';
import '../modules/supporter_screen.dart';
import 'doctor_cases_screen.dart';
import 'delegation_board_screen.dart';
import 'doctor_intake_screen.dart';
import 'doctor_promotion_log_screen.dart';
import 'doctor_rapor_roi_screen.dart';
import 'doctor_result_screen.dart';
import 'doctor_vitals_screen.dart';
import 'dynamic_pricing_screen.dart';
import 'bundle_manager_screen.dart';
import 'health_score_screen.dart';
import 'multi_outlet_screen.dart';
import 'online_catalog_screen.dart';
import 'pos_screen.dart';
import 'progress_tracker_screen.dart';
import 'qr_table_screen.dart';
import 'recipe_screen.dart';
import 'sidak_bos_screen.dart';
import 'whatsapp_broadcast_screen.dart';
import '../../utils/error_messages.dart';
import '../../utils/doctor_result_pdf.dart';
import '../../utils/formatters.dart';
import '../../utils/receipt_generator.dart';
import '../../utils/wa_helper.dart';

import '../../widgets/common/bubble_glass.dart';

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
  Map<String, dynamic>? _briefing;
  Map<String, dynamic>? _dailyDose;
  String _tone = 'bos_tegas';
  int _dailyStreak = 0;
  int _xp = 0;
  int _level = 1;
  static const _levelStep = 100;
  bool _audioAktif = true;
  bool _audioSoundbox = true;
  bool _audioTeguran = true;
  bool _overduePrompted = false;
  bool _reprimandSpoken = false;
  String? _bossWa;
  final SpeechService _speech = SpeechService();
  bool _listening = false;
  String _speechStatus = '';

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
    _loadProfile();
    _loadDailyDose();
    _loadBriefing();
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

  Future<void> _loadProfile() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    try {
      final p = await (widget.service ?? BusinessDoctorService())
          .getProfile(outletId);
      if (!mounted || p == null) return;
      setState(() {
        _tone = p['preferred_tone']?.toString() ?? _tone;
        _dailyStreak =
            int.tryParse(p['daily_streak']?.toString() ?? '') ?? _dailyStreak;
        _xp = int.tryParse(p['xp']?.toString() ?? '') ?? _xp;
        _level = int.tryParse(p['level']?.toString() ?? '') ?? _level;
        _bossWa = p['boss_wa_number']?.toString();
        final audio = p['audio_prefs'];
        if (audio is Map && audio.isNotEmpty) {
          bool pick(String k, bool d) {
            final v = audio[k];
            if (v is bool) return v;
            final s = v?.toString().toLowerCase();
            if (s == 'true' || s == '1' || s == 'ya') return true;
            if (s == 'false' || s == '0' || s == 'tidak') return false;
            return d;
          }

          _audioAktif = pick('aktif', _audioAktif);
          _audioSoundbox = pick('soundbox_pos', _audioSoundbox);
          _audioTeguran = pick('teguran', _audioTeguran);
        }
      });
      VoiceService().applyOutletPrefs(outletId);
    } catch (_) {}
  }

  Future<void> _setTone(String tone) async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    setState(() => _tone = tone);
    try {
      await (widget.service ?? BusinessDoctorService())
          .setPreferredTone(outletId: outletId, tone: tone);
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  Future<void> _editBossWa() async {
    final ctrl = TextEditingController(text: _bossWa ?? '');
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Nomor WhatsApp Bos',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: '08xxxxxxxxxx'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          BubbleButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (res == null) return;
    setState(() => _bossWa = res);
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    try {
      await (widget.service ?? BusinessDoctorService())
          .setBossWaNumber(outletId: outletId, number: res);
      if (mounted) _snack('Nomor Bos disimpan.');
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  String _buildBossMessage() {
    final outletName = ref.read(currentUserProvider)?.name ?? 'Toko';
    final b = StringBuffer();
    b.writeln('*Laporan Toko: $outletName*');
    b.writeln('Tanggal: ${Formatters.date(DateTime.now())}');
    b.writeln('');
    final br = _briefing;
    if (br != null) {
      b.writeln('*Ringkasan Hari Ini*');
      final s = br['summary']?.toString() ?? '';
      if (s.isNotEmpty) b.writeln(s);
      final items = (br['items'] is List) ? br['items'] as List : const [];
      for (final it in items) {
        final m = (it is Map) ? it.cast<String, dynamic>() : const {};
        b.writeln('- ${m['label'] ?? ''}: ${m['text'] ?? ''}');
      }
      b.writeln('');
    }
    final wr = _weeklyReport;
    if (wr != null) {
      b.writeln('*Laporan Mingguan*');
      b.writeln(wr['content']?.toString() ?? '');
      final data = (wr['data'] is Map)
          ? (wr['data'] as Map).cast<String, dynamic>()
          : const {};
      if (data['top_product'] != null) {
        b.writeln('Terlaris: ${data['top_product']}');
      }
      b.writeln('');
    }
    final dd = _dailyDose;
    if (dd != null) {
      b.writeln('*Dosis Harian*');
      b.writeln(dd['title']?.toString() ?? 'Dosis Harian');
    }
    b.writeln('');
    b.writeln('-- dikirim via Dokter Bisnis AI KasirGo');
    return b.toString();
  }

  Future<void> _reportToBoss() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    if (_bossWa == null || _bossWa!.trim().isEmpty) {
      await _editBossWa();
      if (_bossWa == null || _bossWa!.trim().isEmpty) return;
    }
    final msg = _buildBossMessage();
    final ok = await WaHelper.sendWhatsAppMessage(phone: _bossWa!, message: msg);
    if (!mounted) return;
    if (ok) {
      try {
        await (widget.service ?? BusinessDoctorService()).logBossReport(
          outletId: outletId,
          kind: 'laporan',
          summary: _briefing?['summary']?.toString(),
        );
      } catch (_) {}
      _snack('Laporan dibuka di WhatsApp.');
    } else {
      _snack('Tidak bisa membuka WhatsApp.');
    }
  }

  Future<void> _loadDailyDose() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    try {
      final d = await (widget.service ?? BusinessDoctorService())
          .getDailyDose(outletId);
      if (!mounted) return;
      setState(() => _dailyDose = d);
    } catch (_) {}
  }

  Future<void> _loadBriefing() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    try {
      final b = await (widget.service ?? BusinessDoctorService())
          .getBriefing(outletId);
      if (!mounted || b == null) return;
      setState(() => _briefing = b);
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
      _snack(friendlyError(e));
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
      _speakReprimand(r);
    } catch (_) {}
  }

  /// Bacakan teguran Dokter Bisnis (di-gate config Control Plane).
  void _speakReprimand(Map<String, dynamic> r) {
    if (_reprimandSpoken) return;
    _reprimandSpoken = true;
    final title = r['title']?.toString() ?? '';
    final content = r['content']?.toString() ?? '';
    final text = [title, content].where((e) => e.trim().isNotEmpty).join('. ');
    if (text.isNotEmpty) {
      VoiceService().announceReprimand(
        text,
        outletId: ref.read(currentUserProvider)?.outletId,
      );
    }
  }

  /// Simpan master switch suara (dipakai soundbox POS + teguran).
  Future<void> _setAudioPrefs({
    bool? aktif,
    bool? soundbox,
    bool? teguran,
  }) async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    final nextAktif = aktif ?? _audioAktif;
    final nextSoundbox = soundbox ?? _audioSoundbox;
    final nextTeguran = teguran ?? _audioTeguran;
    setState(() {
      _audioAktif = nextAktif;
      _audioSoundbox = nextSoundbox;
      _audioTeguran = nextTeguran;
    });
    try {
      await (widget.service ?? BusinessDoctorService()).setAudioPrefs(
        outletId: outletId,
        aktif: nextAktif,
        soundboxPos: nextSoundbox,
        teguran: nextTeguran,
      );
      await VoiceService().setOutletPrefs(outletId, {
        'aktif': nextAktif,
        'soundbox_pos': nextSoundbox,
        'teguran': nextTeguran,
      });
      if (nextAktif && nextTeguran) {
        await VoiceService().speak('Suara Dokter Bisnis aktif.');
      }
    } catch (e) {
      _snack(friendlyError(e));
    }
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
            BubbleButton(
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
    _speech.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_loading) return;
    if (_listening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() {
        _listening = false;
        _speechStatus = '';
      });
      return;
    }
    final ok = await _speech.start(onResult: (text, finalResult) {
      if (!mounted) return;
      final clean = text.trim();
      setState(() {
        if (clean.isNotEmpty) {
          _input.text = clean;
          _input.selection =
              TextSelection.collapsed(offset: _input.text.length);
        }
        _speechStatus = clean.isEmpty ? 'Mendengarkan...' : 'Mendengar: $clean';
        if (finalResult) _listening = false;
      });
      if (finalResult && clean.isNotEmpty) {
        _speechStatus = '';
        _send(clean, spoken: true);
      }
    });
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _listening = false;
        _speechStatus = '';
      });
      _snack(_speech.error ?? 'Mikrofon tidak tersedia di perangkat ini.');
      return;
    }
    setState(() {
      _listening = true;
      _speechStatus = 'Mendengarkan... bicara sekarang';
    });
  }

  /// Ucapkan jawaban Dokter bila pemilik memakai input suara.
  Future<void> _speakReply(String reply) async {
    if (!_audioAktif) return;
    final clean = reply
        .replaceAll(RegExp(r'[*_`#>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.isEmpty) return;
    final short = clean.length > 700 ? '${clean.substring(0, 700)}...' : clean;
    await VoiceService().speak(short);
  }

  Future<void> _send(String text, {bool spoken = false}) async {
    final message = text.trim();
    if (message.isEmpty || _loading) return;
    if (_listening) {
      await _speech.stop();
      if (mounted) {
        setState(() {
          _listening = false;
          _speechStatus = '';
        });
      }
    }
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
      final hasDose =
          blocks.whereType<Map>().any((b) => b['type'] == 'dose');
      if (hasDose) {
        _loadDailyDose();
        _loadProfile();
      }
      if (spoken && reply.trim().isNotEmpty) {
        _speakReply(reply);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_Msg(
          'assistant',
          friendlyError(e),
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

  Future<void> _openKameraKlinis() async {
    final res = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorVitalsScreen(service: widget.service),
      ),
    );
    if (!mounted || res == null) return;
    final score = int.tryParse(res['score']?.toString() ?? '') ?? 0;
    final gained = int.tryParse(res['gained']?.toString() ?? '') ?? 0;
    final leveled = res['leveled_up'] == true;
    _snack(
      'Skor kesehatan: $score/100. +$gained XP'
      '${leveled ? ' - Naik level!' : ''}',
    );
    _loadIdentity();
    _loadProfile();
  }

  Future<void> _openRaporRoi() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorRaporRoiScreen(service: widget.service),
      ),
    );
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

  /// Buka papan delegasi dengan isian awal dari satu langkah resep.
  Future<void> _onDelegateStep(
      Map<String, dynamic> block, Map<String, dynamic> step, int index) async {
    final text = step['text']?.toString().trim() ?? '';
    if (text.isEmpty) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DelegationBoardScreen(
          initialTitle: text,
          initialBody: 'Langkah ${index + 1} dari resep Dokter Bisnis AI.',
          source: 'prescription',
          sourceRef: block['memory_id']?.toString(),
          stepIndex: index,
        ),
      ),
    );
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
      final key = (memoryId != null && memoryId.isNotEmpty)
          ? memoryId
          : DateTime.now().toIso8601String().substring(0, 10);
      await _awardOnce('resep_selesai', 'resep:$key');
    }
  }

  List<Map<String, dynamic>> _doseItems(Map<String, dynamic> block) =>
      ((block['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  /// Beri XP sekali per aktivitas (aman bila pengguna menandai lalu membatalkan).
  Future<void> _awardOnce(String reason, String eventKey) async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    try {
      final res = await (widget.service ?? BusinessDoctorService()).awardXpOnce(
        outletId: outletId,
        reason: reason,
        eventKey: eventKey,
      );
      final gained = int.tryParse(res['gained']?.toString() ?? '') ?? 0;
      final level = int.tryParse(res['level']?.toString() ?? '') ?? _level;
      final xp = int.tryParse(res['xp']?.toString() ?? '') ?? _xp;
      if (!mounted) return;
      setState(() {
        _xp = xp;
        _level = level;
      });
      if (gained > 0) {
        final up = res['leveled_up'] == true;
        _snack(up ? '+$gained XP - Naik ke level $level!' : '+$gained XP');
      }
    } catch (_) {}
  }

  /// "Jalankan" langkah dosis: buka fitur terkait lalu tandai selesai.
  Future<void> _onDoseStep(
      Map<String, dynamic> block, Map<String, dynamic> step, int index) async {
    final items = _doseItems(block);
    if (index < 0 || index >= items.length) return;
    final key = items[index]['action_key']?.toString() ?? '';
    if (key.isNotEmpty) {
      final hasScreen = key == 'upgrade' ||
          key == 'catat_promosi' ||
          _actionScreen(key) != null;
      if (hasScreen) {
        _handleAction(key, items[index]['text']?.toString() ?? '');
      }
    }
    await _markDoseStep(block, index, true);
  }

  /// Checklist dosis: tandai selesai / batal tanpa membuka fitur.
  Future<void> _toggleDoseStep(Map<String, dynamic> block, int index) async {
    final items = _doseItems(block);
    if (index < 0 || index >= items.length) return;
    final done = items[index]['done'] == true;
    await _markDoseStep(block, index, !done);
  }

  Future<void> _markDoseStep(
      Map<String, dynamic> block, int index, bool done) async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    final items = _doseItems(block);
    if (index < 0 || index >= items.length) return;
    items[index]['done'] = done;
    final doneItems = items.where((e) => e['done'] == true).length;
    final status = doneItems >= items.length
        ? 'done'
        : (doneItems == 0 ? 'pending' : 'partial');
    final updated = {
      ...block,
      'items': items,
      'done_items': doneItems,
      'total_items': items.length,
      'status': status,
    };
    final doseDate = updated['dose_date']?.toString();
    setState(() {
      _dailyDose = updated;
      // Sinkronkan blok dosis di gelembung chat (bila ada) agar langsung tercoret.
      for (var mi = 0; mi < _messages.length; mi++) {
        final msg = _messages[mi];
        if (msg.blocks.isEmpty) continue;
        var changed = false;
        final newBlocks = <dynamic>[];
        for (final raw in msg.blocks) {
          if (raw is Map && raw['type'] == 'dose') {
            final sameRef = identical(raw, block);
            final bd = raw['dose_date']?.toString();
            final sameDate =
                doseDate != null && doseDate.isNotEmpty && bd == doseDate;
            if (sameRef || sameDate) {
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
    try {
      await (widget.service ?? BusinessDoctorService()).updateDailyDose(
        outletId: outletId,
        items: items,
        doneItems: doneItems,
        status: status,
      );
    } catch (_) {}
    if (doneItems >= items.length && items.isNotEmpty && mounted) {
      _snack('Dosis hari ini tuntas. Mantap!');
      _loadProfile();
      final key = (doseDate != null && doseDate.isNotEmpty)
          ? doseDate
          : DateTime.now().toIso8601String().substring(0, 10);
      await _awardOnce('dosis_selesai', 'dosis:$key');
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
    final title =
        p['verdict']?.toString() ?? p['title']?.toString() ?? 'Vonis';
    final body = p['verdict_body']?.toString() ?? '';
    final hint = p['score_hint']?.toString() ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorResultScreen(
          verdictTitle: title,
          verdictBody: body,
          score: score,
          scoreHint: hint,
          targetDays: days,
          dueDate: due,
          steps: steps,
          onRunStep: (i, step) =>
              _onPrescriptionStep(p, Map<String, dynamic>.from(step), i),
          onToggleStep: (i, step) => _togglePrescriptionStep(p, i),
          onStart: () => Navigator.pop(context),
          onShare: () => _shareResult(
            verdictTitle: title,
            verdictBody: body,
            score: score,
            scoreHint: hint,
            targetDays: days,
            dueDate: due,
            steps: steps,
          ),
          onAsk: () {
            Navigator.pop(context);
            _scrollDown();
          },
        ),
      ),
    );
  }

  /// Simpan/Bagikan hasil diagnosa (BAGIAN 13.21A): PDF A4 atau teks WhatsApp.
  Future<void> _shareResult({
    required String verdictTitle,
    required String verdictBody,
    required int? score,
    required String scoreHint,
    required int? targetDays,
    required DateTime? dueDate,
    required List<Map<String, dynamic>> steps,
  }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Simpan / Bagikan Hasil',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Hasil pemeriksaan bisa disimpan sebagai PDF atau dikirim '
                'ke WhatsApp bos.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Simpan / Unduh PDF',
                icon: Icons.picture_as_pdf_rounded,
                height: AppTheme.touchTargetLarge,
                onPressed: () => Navigator.pop(ctx, 'pdf'),
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Kirim ke WhatsApp',
                icon: Icons.chat_rounded,
                variant: AppButtonVariant.outline,
                height: AppTheme.touchTargetLarge,
                onPressed: () => Navigator.pop(ctx, 'wa'),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;

    var storeName = ref.read(currentUserProvider)?.name ?? '';
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (storeName.isEmpty && outletId != null && outletId.isNotEmpty) {
      try {
        storeName =
            (await SupabaseService().getOutlet(outletId))?.businessName ?? '';
      } catch (_) {
        storeName = '';
      }
    }
    if (!mounted) return;

    if (action == 'pdf') {
      try {
        final bytes = await DoctorResultPdf.build(
          storeName: storeName,
          verdictTitle: verdictTitle,
          verdictBody: verdictBody,
          score: score,
          scoreHint: scoreHint,
          targetDays: targetDays,
          dueDate: dueDate,
          steps: steps,
        );
        await ReceiptGenerator.share(
          bytes,
          'Hasil_Diagnosa_${Formatters.date(DateTime.now()).replaceAll('/', '-')}.pdf',
        );
        if (!mounted) return;
        _snack('Hasil pemeriksaan tersimpan sebagai PDF.');
      } catch (e) {
        if (!mounted) return;
        _snack(friendlyError(e,
            fallback: 'Gagal membuat PDF. Silakan coba lagi.'));
      }
      return;
    }

    var phone = _bossWa ?? '';
    if (phone.isEmpty) {
      _snack('Atur nomor WhatsApp bos dulu ya.');
      await _editBossWa();
      phone = _bossWa ?? '';
      if (phone.isEmpty) return;
    }
    final text = DoctorResultPdf.buildText(
      storeName: storeName,
      verdictTitle: verdictTitle,
      verdictBody: verdictBody,
      score: score,
      targetDays: targetDays,
      dueDate: dueDate,
      steps: steps,
    );
    final ok = await WaHelper.sendWhatsAppMessage(phone: phone, message: text);
    if (!mounted) return;
    if (!ok) _snack('WhatsApp tidak bisa dibuka di perangkat ini.');
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
        return const SupporterFeatureGate(
          featureKey: 'sidak_bos',
          title: 'Sidak Stok & Kas',
          child: SidakBosScreen(),
        );
      case 'progress_tracker':
        return const SupporterFeatureGate(
          featureKey: 'progress_tracker',
          title: 'Laporan & Progres',
          child: ProgressTrackerScreen(),
        );
      case 'dynamic_pricing':
        return const SupporterFeatureGate(
          featureKey: 'dynamic_pricing',
          title: 'Atur Harga & Diskon',
          child: DynamicPricingScreen(),
        );
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
        // QR Meja hanya untuk usaha makanan (cafe/warteg/resto).
        if (!_isFoodBusiness()) return null;
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
      default:
        return null;
    }
  }

  /// QR Meja & KDS hanya relevan untuk usaha makanan (cafe/warteg/resto).
  bool _isFoodBusiness() {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return false;
    return ModuleConfig.isFoodBusiness(ref.read(outletTypeProvider(outletId)));
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
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                gradient: AppTheme.aiBadgeGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'AI',
                style: GoogleFonts.plusJakartaSans(
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
            tooltip: 'Lapor ke Bos',
            icon: const Icon(Icons.forward_to_inbox_rounded),
            onPressed: _reportToBoss,
          ),
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

  /// Peta resep sudah tampil di dalam gelembung chat?
  bool get _chatShowsRecipe => _messages.any((m) => m.blocks.any((b) {
        if (b is! Map) return false;
        if (b['type'] == 'prescription') return true;
        if (b['type'] != 'checklist') return false;
        return (b['title']?.toString().toLowerCase() ?? '').contains('resep');
      }));

  Widget _buildList() {
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      children: [
        if (_identity != null) ...[
          _buildIdentityCard(),
          const SizedBox(height: 12),
        ],
        _buildPersonaBar(),
        const SizedBox(height: 12),
        _buildAudioCard(),
        const SizedBox(height: 12),
        _buildDelegationCard(),
        const SizedBox(height: 12),
        if (_briefing != null) ...[
          _buildBriefingCard(),
          const SizedBox(height: 12),
        ],
        if (_dailyDose != null) ...[
          _buildDailyDoseCard(),
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
          // Bila chat sudah menampilkan peta resep, jangan ulangi kartu yang sama.
          if (!_chatShowsRecipe) ...[
            DoctorBlocks(
              blocks: [_activePrescription!],
              onPrescription: _onPrescriptionStep,
              onTogglePrescription: _togglePrescriptionStep,
              onDelegate: _onDelegateStep,
            ),
            const SizedBox(height: 8),
          ],
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
        _buildKameraKlinisCta(),
        const SizedBox(height: 12),
        _buildRaporRoiCta(),
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
            style: GoogleFonts.plusJakartaSans(
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
                  style: GoogleFonts.plusJakartaSans(
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
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: scoreColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGamificationRow(),
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
              if (_dailyStreak > 0)
                _identityChip('Streak $_dailyStreak hari',
                    color: AppTheme.successColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGamificationRow() {
    final inLevel = _xp % _levelStep;
    final progress = (inLevel / _levelStep).clamp(0.0, 1.0);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.military_tech_rounded,
                  size: 15, color: AppTheme.primaryColor),
              const SizedBox(width: 4),
              Text(
                'Level $_level',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppTheme.surfaceMutedColor,
                  valueColor:
                      const AlwaysStoppedAnimation(AppTheme.primaryColor),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$inLevel / $_levelStep XP menuju level ${_level + 1}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
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
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  static const _tonePresets = [
    [
      'bos_tegas',
      'Bos Tegas',
      'Tegas & to the point',
      Icons.gavel_rounded,
    ],
    [
      'partner_santai',
      'Partner Santai',
      'Ramah & membesarkan hati',
      Icons.weekend_outlined,
    ],
    [
      'analis_taktis',
      'Analis Taktis',
      'Tenang & berbasis data',
      Icons.query_stats_rounded,
    ],
  ];

  Widget _buildPersonaBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
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
              const Icon(Icons.record_voice_over_outlined,
                  color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Persona Dokter',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            children: [
              for (final t in _tonePresets) ...[
                _personaTile(
                  key: t[0] as String,
                  label: t[1] as String,
                  hint: t[2] as String,
                  icon: t[3] as IconData,
                ),
                if (t != _tonePresets.last) const SizedBox(height: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _personaTile({
    required String key,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    final selected = _tone == key;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Persona $label',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        onTap: () => _setTone(key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color:
                selected ? AppTheme.infoSoftColor : AppTheme.surfaceMutedColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    size: 18, color: AppTheme.primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
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
              const Icon(Icons.volume_up_rounded,
                  color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Suara Interaktif',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Switch(
                value: _audioAktif,
                activeThumbColor: AppTheme.primaryColor,
                onChanged: (v) => _setAudioPrefs(aktif: v),
              ),
            ],
          ),
          Text(
            _audioAktif
                ? 'Dokter Bisnis boleh bersuara di outlet ini.'
                : 'Semua suara dimatikan untuk outlet ini.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          _audioTile(
            label: 'Soundbox POS',
            hint: 'Bacakan nominal pembayaran saat transaksi sukses.',
            value: _audioSoundbox && _audioAktif,
            onChanged: _audioAktif
                ? (v) => _setAudioPrefs(soundbox: v)
                : null,
          ),
          Divider(height: 1, color: AppTheme.borderColor),
          _audioTile(
            label: 'Teguran Suara',
            hint: 'Bacakan teguran Dokter Bisnis agar langsung terdengar.',
            value: _audioTeguran && _audioAktif,
            onChanged:
                _audioAktif ? (v) => _setAudioPrefs(teguran: v) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDelegationCard() {
    return Material(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DelegationBoardScreen()),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment_ind_rounded,
                    color: AppTheme.secondaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delegasi Tugas',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Bagi langkah resep ke Admin, Kasir, atau Koki.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _audioTile({
    required String label,
    required String hint,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: onChanged == null
                        ? AppTheme.textSecondary
                        : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppTheme.primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  IconData _briefIcon(String? icon) {
    switch (icon) {
      case 'weather':
        return Icons.wb_sunny_rounded;
      case 'calendar':
        return Icons.event_rounded;
      case 'stock':
        return Icons.inventory_2_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Widget _buildBriefingCard() {
    final b = _briefing!;
    final items = ((b['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final date = b['briefing_date']?.toString() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  gradient: AppTheme.aiBadgeGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wb_twilight_rounded,
                    size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Apel Pagi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (date.isNotEmpty)
                      Text(
                        date,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Tutup',
                icon: const Icon(Icons.close, size: 18),
                color: AppTheme.textSecondary,
                onPressed: () => setState(() => _briefing = null),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            b['summary']?.toString() ?? '',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.45,
              color: AppTheme.textPrimary,
            ),
          ),
          for (final it in items) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_briefIcon(it['icon']?.toString()),
                    size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        it['label']?.toString() ?? '',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        it['text']?.toString() ?? '',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          height: 1.4,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDailyDoseCard() {
    final block = <String, dynamic>{..._dailyDose!, 'type': 'dose'};
    return DoctorBlocks(
      blocks: [block],
      onDoseStep: _onDoseStep,
      onToggleDose: _toggleDoseStep,
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
                  style: GoogleFonts.plusJakartaSans(
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.45,
              color: AppTheme.textPrimary,
            ),
          ),
          if (data['top_product'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Terlaris: ${data['top_product']}',
              style: GoogleFonts.plusJakartaSans(
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
                  style: GoogleFonts.plusJakartaSans(
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          if ((a['body']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              a['body'].toString(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.4,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'AI mengusulkan aksi ini tetapi BELUM dijalankan. Anda yang memutuskan.',
            style: GoogleFonts.plusJakartaSans(
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
                  style: GoogleFonts.plusJakartaSans(
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
            style: GoogleFonts.plusJakartaSans(
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
                    style: GoogleFonts.plusJakartaSans(
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
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700, color: color)),
                const SizedBox(height: 2),
                Text(body,
                    style: GoogleFonts.plusJakartaSans(
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
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'Tanya apa saja soal omzet, stok, promosi, atau arus kas '
                      'usaha Anda.',
                      style: GoogleFonts.plusJakartaSans(
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
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'Diagnosa lebih akurat dengan 3 langkah singkat.',
                      style: GoogleFonts.plusJakartaSans(
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

  Widget _buildKameraKlinisCta() {
    return Material(
      color: AppTheme.moduleAccentTeal.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        onTap: _openKameraKlinis,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(
                color: AppTheme.moduleAccentTeal.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.moduleAccentTeal,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: const Icon(Icons.photo_camera_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kamera Klinis',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'Foto kondisi toko + nilai 1-5, dapatkan skor kesehatan.',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.moduleAccentTeal),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRaporRoiCta() {
    return Material(
      color: AppTheme.moduleAccentIndigo.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        onTap: _openRaporRoi,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(
                color: AppTheme.moduleAccentIndigo.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.moduleAccentIndigo,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: const Icon(Icons.insights_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rapor ROI Promosi',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'Lihat promosi mana yang paling menguntungkan.',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.moduleAccentIndigo),
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
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'Sudah dijalankan? Beri tahu hasilnya, Dokter perbaiki resepnya.',
                      style: GoogleFonts.plusJakartaSans(
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
                  style: GoogleFonts.plusJakartaSans(
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
                style: GoogleFonts.plusJakartaSans(
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
    // Kartu dosis harian sudah tampil menetap di atas chat; sembunyikan versi
    // di dalam gelembung agar hasil diagnosa tidak dobel.
    final blocks = _dailyDose == null
        ? msg.blocks
        : msg.blocks
            .where((b) => !(b is Map && b['type'] == 'dose'))
            .toList();
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
            style: GoogleFonts.plusJakartaSans(
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
            child: blocks.isEmpty
                ? Text(
                    msg.text.isEmpty ? 'Maaf, tidak ada jawaban.' : msg.text,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      height: 1.45,
                      color: AppTheme.textPrimary,
                    ),
                  )
                : DoctorBlocks(
                    blocks: blocks,
                    onChoice: _send,
                    onAction: _handleAction,
                    onPrescription: _onPrescriptionStep,
                    onTogglePrescription: _togglePrescriptionStep,
                    onDelegate: _onDelegateStep,
                    onDoseStep: _onDoseStep,
                    onToggleDose: _toggleDoseStep,
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
                  style: GoogleFonts.plusJakartaSans(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_listening || _speechStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      _listening ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                      size: 16,
                      color: _listening
                          ? AppTheme.errorColor
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _speechStatus.isEmpty
                            ? 'Mendengarkan...'
                            : _speechStatus,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: _listening
                              ? AppTheme.errorColor
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _loading ? null : _send,
                    decoration: InputDecoration(
                      hintText: _listening
                          ? 'Sedang mendengarkan suara Anda...'
                          : 'Tulis atau ucapkan pertanyaan bisnis Anda...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: AppTheme.touchTargetMedium,
                  height: AppTheme.touchTargetMedium,
                  child: Tooltip(
                    message: _listening ? 'Berhenti merekam' : 'Bicara',
                    child: Container(
                      decoration: BoxDecoration(
                        color: _listening
                            ? AppTheme.errorSoftColor
                            : AppTheme.surfaceMutedColor,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                        border: Border.all(
                          color: _listening
                              ? AppTheme.errorColor
                              : AppTheme.borderColor,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                          onTap: _loading ? null : _toggleMic,
                          child: Icon(
                            _listening
                                ? Icons.stop_circle_rounded
                                : Icons.mic_rounded,
                            color: _listening
                                ? AppTheme.errorColor
                                : AppTheme.textPrimary,
                            size: 22,
                          ),
                        ),
                      ),
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
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                        onTap: _loading ? null : () => _send(_input.text),
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
