import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/delegation_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_dropdown_field.dart';
import '../../widgets/common/centennial_background.dart';

/// Papan delegasi tugas Dokter Bisnis ke Admin / Kasir / Koki.
///
/// Owner membuka layar ini dari kartu "Delegasi Tugas" di Dokter Bisnis AI.
/// Staf memakai [DelegationTasksCard] di beranda masing-masing.
class DelegationBoardScreen extends ConsumerStatefulWidget {
  const DelegationBoardScreen({
    super.key,
    this.service,
    this.initialTitle,
    this.initialBody,
    this.source = 'manual',
    this.sourceRef,
    this.stepIndex,
  });

  final DelegationService? service;
  final String? initialTitle;
  final String? initialBody;
  final String source;
  final String? sourceRef;
  final int? stepIndex;

  @override
  ConsumerState<DelegationBoardScreen> createState() =>
      _DelegationBoardScreenState();
}

class _DelegationBoardScreenState extends ConsumerState<DelegationBoardScreen> {
  late final DelegationService _service =
      widget.service ?? DelegationService();

  List<DoctorDelegation> _items = const [];
  List<Map<String, dynamic>> _staff = const [];
  Map<String, dynamic> _summary = const {};
  bool _loading = true;
  String _filter = 'aktif';

  static const _filters = <({String key, String label})>[
    (key: 'aktif', label: 'Aktif'),
    (key: 'selesai', label: 'Selesai'),
    (key: 'semua', label: 'Semua'),
  ];

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      if (!mounted) return;
      if ((widget.initialTitle ?? '').trim().isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSheet(null);
      });
    });
  }

  Future<void> _load() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final items = await _service.listForOutlet(outletId);
    final staff = await _service.staffOptions(outletId);
    final summary = await _service.summary(outletId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _staff = staff;
      _summary = summary;
      _loading = false;
    });
  }

  List<DoctorDelegation> get _visible {
    switch (_filter) {
      case 'selesai':
        return _items.where((d) => d.isClosed).toList();
      case 'semua':
        return _items;
      default:
        return _items.where((d) => !d.isClosed).toList();
    }
  }

  int get _overdueCount => _items.where((d) => d.isOverdue).length;

  Future<void> _toast(String text, {bool error = false}) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppTheme.errorColor : AppTheme.successColor,
      ),
    );
  }

  Future<void> _setStatus(DoctorDelegation item, String status) async {
    final res = await _service.setStatus(item.id, status);
    if (!mounted) return;
    if (res['ok'] == false) {
      await _toast(
        res['error']?.toString() ?? 'Gagal mengubah status tugas.',
        error: true,
      );
      return;
    }
    await _load();
    if (status == 'selesai') {
      final xp = res['xp'];
      await _toast(xp == null
          ? 'Tugas ditandai selesai.'
          : 'Tugas selesai. Staf mendapat $xp XP.');
    } else {
      await _toast('Status tugas diperbarui.');
    }
  }

  Future<void> _delete(DoctorDelegation item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        title: Text(
          'Hapus tugas ini?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          item.title,
          style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.delete(item.id);
    await _load();
    await _toast('Tugas dihapus.');
  }

  Future<void> _openSheet(DoctorDelegation? item) async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (_) => _DelegationForm(
        service: _service,
        outletId: outletId,
        staff: _staff,
        item: item,
        presetTitle: item == null ? widget.initialTitle : null,
        presetBody: item == null ? widget.initialBody : null,
        source: item == null ? widget.source : null,
        sourceRef: item == null ? widget.sourceRef : null,
        stepIndex: item == null ? widget.stepIndex : null,
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Delegasi Tugas',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'delegation-create-fab',
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        onPressed: () => _openSheet(null),
        icon: const Icon(Icons.add_task_rounded),
        label: Text(
          'Tugas Baru',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: CentennialBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppTheme.contentMaxWidth),
              child: RefreshIndicator(
                color: AppTheme.primaryColor,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    _summaryRow(),
                    const SizedBox(height: 16),
                    _filterRow(),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      )
                    else if (_visible.isEmpty)
                      _emptyState()
                    else
                      for (final item in _visible) ...[
                        _delegationCard(item),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow() {
    int n(String key) => (int.tryParse('${_summary[key] ?? 0}') ?? 0);
    return Row(
      children: [
        _statCard('Aktif', n('pending'), AppTheme.primaryColor),
        const SizedBox(width: 8),
        _statCard('Dikerjakan', n('dikerjakan'), AppTheme.warningColor),
        const SizedBox(width: 8),
        _statCard('Selesai', n('selesai'), AppTheme.successColor),
        const SizedBox(width: 8),
        _statCard('Terlambat', _overdueCount, AppTheme.errorColor),
      ],
    );
  }

  Widget _statCard(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterRow() {
    return Wrap(
      spacing: 8,
      children: [
        for (final f in _filters)
          ChoiceChip(
            label: Text(f.label),
            selected: _filter == f.key,
            onSelected: (_) => setState(() => _filter = f.key),
            labelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _filter == f.key
                  ? Colors.white
                  : AppTheme.textSecondary,
            ),
            selectedColor: AppTheme.primaryColor,
            backgroundColor: AppTheme.surfaceColor,
            side: const BorderSide(color: AppTheme.borderColor),
          ),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.checklist_rounded,
              size: 40, color: AppTheme.primaryColor),
          const SizedBox(height: 10),
          Text(
            _filter == 'selesai'
                ? 'Belum ada tugas yang selesai.'
                : 'Belum ada tugas aktif. Buat tugas agar staf tahu apa yang harus dikerjakan.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'selesai':
        return AppTheme.successColor;
      case 'dikerjakan':
        return AppTheme.warningColor;
      case 'dilewati':
        return AppTheme.textSecondary;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'selesai':
        return 'Selesai';
      case 'dikerjakan':
        return 'Dikerjakan';
      case 'dilewati':
        return 'Dilewati';
      default:
        return 'Menunggu';
    }
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'operasional':
        return 'Operasional';
      case 'promosi':
        return 'Promosi';
      case 'stok':
        return 'Stok';
      case 'keuangan':
        return 'Keuangan';
      case 'layanan':
        return 'Layanan';
      default:
        return 'Lainnya';
    }
  }

  Widget _delegationCard(DoctorDelegation item) {
    final color = _statusColor(item.status);
    final overdue = item.isOverdue;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: overdue ? AppTheme.errorColor : AppTheme.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    decoration:
                        item.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _badge(_statusLabel(item.status), color),
            ],
          ),
          if (item.body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.body,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                height: 1.4,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _badge(_categoryLabel(item.category), AppTheme.secondaryColor,
                  soft: true),
              if (item.priority != 'normal')
                _badge(
                  item.priority == 'tinggi' ? 'Prioritas Tinggi' : 'Prioritas Rendah',
                  item.priority == 'tinggi'
                      ? AppTheme.errorColor
                      : AppTheme.textSecondary,
                  soft: true,
                ),
              if (item.source != 'manual')
                _badge(
                  item.source == 'prescription'
                      ? 'Dari Resep'
                      : item.source == 'dose'
                          ? 'Dari Dosis Harian'
                          : 'Dari Briefing',
                  AppTheme.moduleAccentViolet,
                  soft: true,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 15, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.assignedName.isEmpty
                      ? 'Belum ditugaskan'
                      : '${item.assignedName}${item.assignedRole.isEmpty ? '' : ' • ${item.assignedRole}'}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              if (item.dueAt != null) ...[
                Icon(
                  overdue
                      ? Icons.alarm_rounded
                      : Icons.event_available_rounded,
                  size: 15,
                  color: overdue ? AppTheme.errorColor : AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  _dueLabel(item.dueAt!),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: overdue
                        ? AppTheme.errorColor
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          if (item.doneNote != null && item.doneNote!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Catatan staf: ${item.doneNote}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (!item.isClosed)
                Expanded(
                  child: SizedBox(
                    height: AppTheme.touchTargetMedium,
                    child: AppButton(
                      label: item.isWorking ? 'Selesai' : 'Tandai Selesai',
                      icon: Icons.check_circle_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => _setStatus(item, 'selesai'),
                    ),
                  ),
                ),
              if (!item.isClosed) const SizedBox(width: 8),
              _iconAction(
                icon: Icons.edit_rounded,
                tooltip: 'Ubah tugas',
                onTap: () => _openSheet(item),
              ),
              const SizedBox(width: 8),
              _iconAction(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Hapus tugas',
                color: AppTheme.errorColor,
                onTap: () => _delete(item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _dueLabel(DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(due.year, due.month, due.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Besok';
    if (diff < 0) return 'Lewat ${-diff} hari';
    return '$diff hari lagi';
  }

  Widget _badge(String text, Color color, {bool soft = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: soft ? color.withValues(alpha: 0.1) : color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: soft ? color : Colors.white,
        ),
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = AppTheme.textSecondary,
  }) {
    return SizedBox(
      width: AppTheme.touchTargetMedium,
      height: AppTheme.touchTargetMedium,
      child: Material(
        color: AppTheme.surfaceMutedColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: onTap,
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

/// Form buat/ubah tugas (bottom sheet).
class _DelegationForm extends StatefulWidget {
  const _DelegationForm({
    required this.service,
    required this.outletId,
    required this.staff,
    this.item,
    this.presetTitle,
    this.presetBody,
    this.source,
    this.sourceRef,
    this.stepIndex,
  });

  final DelegationService service;
  final String outletId;
  final List<Map<String, dynamic>> staff;
  final DoctorDelegation? item;
  final String? presetTitle;
  final String? presetBody;
  final String? source;
  final String? sourceRef;
  final int? stepIndex;

  @override
  State<_DelegationForm> createState() => _DelegationFormState();
}

class _DelegationFormState extends State<_DelegationForm> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late String _category;
  late String _priority;
  late String _assignee;
  late String _due;
  bool _saving = false;

  static const _categories = <({String key, String label})>[
    (key: 'operasional', label: 'Operasional'),
    (key: 'promosi', label: 'Promosi'),
    (key: 'stok', label: 'Stok'),
    (key: 'keuangan', label: 'Keuangan'),
    (key: 'layanan', label: 'Layanan'),
    (key: 'lainnya', label: 'Lainnya'),
  ];

  static const _dueOptions = <({String key, String label})>[
    (key: 'hari_ini', label: 'Hari ini'),
    (key: 'besok', label: 'Besok'),
    (key: '3hari', label: '3 hari'),
    (key: '7hari', label: '7 hari'),
    (key: 'tanpa', label: 'Tanpa tenggat'),
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(
      text: item?.title ?? widget.presetTitle ?? '',
    );
    _body = TextEditingController(text: item?.body ?? widget.presetBody ?? '');
    _category = item?.category ?? 'operasional';
    _priority = item?.priority ?? 'normal';
    _assignee = item?.assignedUserId ?? '';
    _due = item == null
        ? (widget.presetTitle == null ? 'besok' : 'hari_ini')
        : _dueKeyFor(item.dueAt);
  }

  String _dueKeyFor(DateTime? due) {
    if (due == null) return 'tanpa';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(due.year, due.month, due.day);
    final diff = target.difference(today).inDays;
    if (diff <= 0) return 'hari_ini';
    if (diff == 1) return 'besok';
    if (diff <= 3) return '3hari';
    return '7hari';
  }

  DateTime? get _dueDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_due) {
      case 'hari_ini':
        return today.add(const Duration(hours: 20));
      case 'besok':
        return today.add(const Duration(days: 1, hours: 20));
      case '3hari':
        return today.add(const Duration(days: 3, hours: 20));
      case '7hari':
        return today.add(const Duration(days: 7, hours: 20));
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  String get _assigneeName {
    for (final s in widget.staff) {
      if (s['user_id']?.toString() == _assignee) {
        return s['display_name']?.toString() ??
            'Staf (${s['role']?.toString().toUpperCase() ?? ''})';
      }
    }
    return '';
  }

  String get _assigneeRole {
    for (final s in widget.staff) {
      if (s['user_id']?.toString() == _assignee) {
        return s['role']?.toString() ?? '';
      }
    }
    return '';
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul tugas wajib diisi.')),
      );
      return;
    }
    setState(() => _saving = true);
    final body = _body.text.trim();
    bool ok;
    final item = widget.item;
    if (item == null) {
      final id = await widget.service.create(
        outletId: widget.outletId,
        title: title,
        body: body.isEmpty ? null : body,
        category: _category,
        source: widget.source ?? 'manual',
        sourceRef: widget.sourceRef,
        stepIndex: widget.stepIndex,
        assignedUserId: _assignee.isEmpty ? null : _assignee,
        assignedName: _assigneeName,
        assignedRole: _assigneeRole,
        priority: _priority,
        dueAt: _dueDate,
      );
      ok = id != null;
    } else {
      ok = await widget.service.update(
        item.id,
        title: title,
        body: body,
        category: _category,
        priority: _priority,
        assignedUserId: _assignee,
        assignedName: _assigneeName,
        assignedRole: _assigneeRole,
        dueAt: _dueDate,
        clearDue: _due == 'tanpa',
      );
    }
    if (!mounted) return;
    if (!ok) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan tugas. Silakan coba lagi.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final options = <String>[
      for (final s in widget.staff)
        if ((s['user_id']?.toString() ?? '').isNotEmpty)
          s['display_name']?.toString() ??
              'Staf (${s['role']?.toString().toUpperCase() ?? ''})',
    ];
    final currentName = _assigneeName.isEmpty ? null : _assigneeName;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item == null ? 'Tugas Baru' : 'Ubah Tugas',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Judul tugas'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Detail / cara mengerjakan (opsional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            _label('Kategori'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _categories)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _category == c.key,
                    onSelected: (_) => setState(() => _category = c.key),
                    labelStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _category == c.key
                          ? Colors.white
                          : AppTheme.textSecondary,
                    ),
                    selectedColor: AppTheme.primaryColor,
                    backgroundColor: AppTheme.surfaceColor,
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _label('Prioritas'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final p in const [
                  (key: 'rendah', label: 'Rendah'),
                  (key: 'normal', label: 'Normal'),
                  (key: 'tinggi', label: 'Tinggi'),
                ])
                  ChoiceChip(
                    label: Text(p.label),
                    selected: _priority == p.key,
                    onSelected: (_) => setState(() => _priority = p.key),
                    labelStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _priority == p.key
                          ? Colors.white
                          : AppTheme.textSecondary,
                    ),
                    selectedColor: AppTheme.primaryColor,
                    backgroundColor: AppTheme.surfaceColor,
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AppDropdownField(
              label: 'Tugaskan ke',
              value: currentName,
              hint: 'Pilih staf',
              allLabel: 'Belum ditugaskan',
              prefixIcon: Icons.person_outline_rounded,
              options: options,
              onChanged: (v) {
                if (v == null) {
                  setState(() => _assignee = '');
                  return;
                }
                for (final s in widget.staff) {
                  final name = s['display_name']?.toString() ??
                      'Staf (${s['role']?.toString().toUpperCase() ?? ''})';
                  if (name == v) {
                    setState(() => _assignee = s['user_id']?.toString() ?? '');
                    return;
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            _label('Tenggat'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in _dueOptions)
                  ChoiceChip(
                    label: Text(d.label),
                    selected: _due == d.key,
                    onSelected: (_) => setState(() => _due = d.key),
                    labelStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _due == d.key
                          ? Colors.white
                          : AppTheme.textSecondary,
                    ),
                    selectedColor: AppTheme.primaryColor,
                    backgroundColor: AppTheme.surfaceColor,
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            AppButton(
              label: widget.item == null ? 'Buat Tugas' : 'Simpan Perubahan',
              icon: Icons.save_rounded,
              isLoading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      );
}
