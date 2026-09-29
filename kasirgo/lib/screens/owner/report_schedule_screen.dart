import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../services/report_scheduler_service.dart';
import '../../utils/formatters.dart';

class ReportScheduleScreen extends ConsumerStatefulWidget {
  const ReportScheduleScreen({super.key});

  @override
  ConsumerState<ReportScheduleScreen> createState() =>
      _ReportScheduleScreenState();
}

class _ReportScheduleScreenState extends ConsumerState<ReportScheduleScreen> {
  final _svc = ReportSchedulerService();
  final List<TextEditingController> _recipientCtrls = [];

  bool _loading = true;
  bool _saving = false;
  String? _outletId;
  String? _businessName;

  ReportSchedule _schedule = const ReportSchedule();
  Map<String, dynamic> _flags = Map<String, dynamic>.from(
      const ReportSchedule().contentFlags);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _recipientCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _outletId = outletId;

    try {
      final outlet = await Supabase.instance.client
          .from('outlets')
          .select('name')
          .eq('id', outletId)
          .maybeSingle();
      _businessName = outlet?['name']?.toString();
    } catch (_) {}

    final loaded = await _svc.load(outletId);
    _schedule = loaded ?? const ReportSchedule();
    _flags = _schedule.contentFlags.isEmpty
        ? Map<String, dynamic>.from(const ReportSchedule().contentFlags)
        : Map<String, dynamic>.from(_schedule.contentFlags);

    _recipientCtrls.clear();
    for (final r in _schedule.recipients) {
      _recipientCtrls.add(TextEditingController(text: r));
    }
    if (_recipientCtrls.isEmpty) _recipientCtrls.add(TextEditingController());

    if (mounted) setState(() => _loading = false);
  }

  List<String> _collectRecipients() => _recipientCtrls
      .map((c) => c.text.trim())
      .where((v) => v.isNotEmpty)
      .take(ReportSchedulerService.maxRecipients)
      .toList();

  Future<void> _pickTime() async {
    final parts = _schedule.sendTime.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.isNotEmpty ? parts[0] : '21') ?? 21,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      ),
    );
    if (picked != null) {
      setState(() => _schedule = _schedule.copyWith(
            sendTime:
                '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
          ));
    }
  }

  Future<void> _save() async {
    if (_outletId == null) return;
    final recipients = _collectRecipients();
    if (_schedule.enabled && recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Isi minimal 1 penerima laporan.'),
        backgroundColor: AppTheme.errorColor,
      ));
      return;
    }

    setState(() => _saving = true);
    final toSave = _schedule.copyWith(
      recipients: recipients,
      contentFlags: _flags,
    );
    final ok = await _svc.save(_outletId!, toSave);
    if (ok) {
      await _svc.applyLocalReminder(_outletId!, toSave);
      await NotificationService.instance.initialize();
      await _load();
    }
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? (_schedule.enabled
                ? 'Jadwal laporan tersimpan. Pengingat disetel.'
                : 'Jadwal disimpan (nonaktif).')
            : 'Gagal menyimpan jadwal. Coba lagi.'),
        backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
      ));
    }
  }

  Future<void> _sendNow() async {
    if (_outletId == null) return;
    final recipients = _collectRecipients();
    if (recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Isi minimal 1 penerima laporan.'),
        backgroundColor: AppTheme.errorColor,
      ));
      return;
    }
    final temp = _schedule.copyWith(recipients: recipients, contentFlags: _flags);
    final ok = _schedule.channels.contains('email')
        ? await _sendEmailPdf(temp, recipients)
        : await _svc.sendViaWhatsApp(_outletId!, temp,
            businessName: _businessName);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tidak bisa membuka aplikasi tujuan.'),
        backgroundColor: AppTheme.errorColor,
      ));
    }
  }

  /// Buat PDF laporan lalu bagikan (email/WhatsApp) lewat share sheet.
  Future<bool> _sendEmailPdf(ReportSchedule s, List<String> recipients) async {
    try {
      final text =
          await _svc.buildReportText(_outletId!, s, businessName: _businessName);
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => [
            pw.Header(
              level: 0,
              child: pw.Text('Laporan KasirGo',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 8),
            pw.Text(text, style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 16),
            pw.Text('Dibuat otomatis oleh KasirGo Super-App UMKM.',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey700)),
          ],
        ),
      );
      final bytes = await doc.save();
      final email =
          recipients.firstWhere((r) => r.contains('@'), orElse: () => '');
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Laporan_KasirGo.pdf',
        subject: 'Laporan KasirGo${_businessName != null ? " - $_businessName" : ""}',
        body: email.isNotEmpty ? 'Kepada: $email\n\n$text' : text,
      );
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal membuat PDF: $e'),
          backgroundColor: AppTheme.errorColor,
        ));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Laporan Otomatis ke Bos'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _card(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: AppTheme.primaryColor,
                        value: _schedule.enabled,
                        onChanged: (v) => setState(
                            () => _schedule = _schedule.copyWith(enabled: v)),
                        title: const Text('Aktifkan laporan otomatis',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary)),
                        subtitle: const Text(
                          'Pengingat muncul di HP; ketuk untuk kirim via '
                          'WhatsApp/email dengan laporan siap pakai.',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle('Periode'),
                    Wrap(
                      spacing: 8,
                      children: [
                        _periodChip('Harian', 'daily'),
                        _periodChip('Mingguan', 'weekly'),
                        _periodChip('Bulanan', 'monthly'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _card(
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.schedule,
                                color: AppTheme.primaryColor),
                            title: const Text('Jam kirim'),
                            trailing: Text(_schedule.sendTime,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor)),
                            onTap: _pickTime,
                          ),
                          if (_schedule.period == 'weekly') ...[
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Hari',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary)),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              children: [
                                for (var d = 1; d <= 7; d++)
                                  _dayChip(d),
                              ],
                            ),
                          ],
                          if (_schedule.period == 'monthly') ...[
                            const Divider(height: 1),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Tanggal'),
                              trailing: DropdownButton<int>(
                                value: (_schedule.dayOfMonth ?? 1).clamp(1, 28),
                                underline: const SizedBox.shrink(),
                                items: [
                                  for (var d = 1; d <= 28; d++)
                                    DropdownMenuItem(
                                        value: d, child: Text('$d')),
                                ],
                                onChanged: (v) => setState(() => _schedule =
                                    _schedule.copyWith(dayOfMonth: v)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle('Penerima (maks 3)'),
                    Column(
                      children: [
                        for (var i = 0; i < _recipientCtrls.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _recipientCtrls[i],
                                    keyboardType: TextInputType.text,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: '08xxxxxxxxxx atau email@bos.com',
                                      prefixIcon: const Icon(Icons.person,
                                          color: AppTheme.textSecondary),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                if (_recipientCtrls.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        color: AppTheme.errorColor),
                                    onPressed: () => setState(() {
                                      _recipientCtrls.removeAt(i).dispose();
                                    }),
                                  ),
                              ],
                            ),
                          ),
                        if (_recipientCtrls.length <
                            ReportSchedulerService.maxRecipients)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => setState(() =>
                                  _recipientCtrls.add(TextEditingController())),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Tambah penerima'),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle('Isi laporan'),
                    _card(
                      child: Column(
                        children: [
                          for (final entry
                              in ReportSchedulerService.contentLabels.entries)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              activeThumbColor: AppTheme.primaryColor,
                              value: _flags[entry.key] == true,
                              onChanged: (v) => setState(
                                  () => _flags[entry.key] = v),
                              title: Text(entry.value,
                                  style: const TextStyle(fontSize: 13.5)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle('Kanal'),
                    Wrap(
                      spacing: 8,
                      children: [
                        _channelChip('WhatsApp', 'wa'),
                        _channelChip('Email (PDF)', 'email'),
                      ],
                    ),
                    if (_schedule.enabled) ...[
                      const SizedBox(height: 12),
                      Consumer(builder: (context, ref, _) {
                        final next = _svc.nextRun(_schedule);
                        if (next == null) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.event_available,
                                  color: AppTheme.primaryColor, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Jadwal berikutnya: ${Formatters.dateTime(next)}'
                                  '${NotificationService.instance.isReady ? "" : " (pengingat perlu izin notifikasi)"}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _sendNow,
                            icon: const Icon(Icons.send, size: 18),
                            label: const Text('Kirim Sekarang'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save, size: 18),
                            label: const Text('Simpan Jadwal'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Catatan: pengingat lokal berjalan di HP. Pengiriman '
                      'email/PDF otomatis penuh dijalankan oleh Edge Function '
                      'terjadwal (di-deploy terpisah).',
                      style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: child,
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
        ),
      );

  Widget _periodChip(String label, String value) {
    final selected = _schedule.period == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
          color: selected ? Colors.white : AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
      onSelected: (_) => setState(() => _schedule = _schedule.copyWith(
            period: value,
            dayOfWeek: value == 'weekly' ? (_schedule.dayOfWeek ?? 1) : null,
            dayOfMonth: value == 'monthly' ? (_schedule.dayOfMonth ?? 1) : null,
          )),
    );
  }

  Widget _dayChip(int day) {
    const names = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final selected = (_schedule.dayOfWeek ?? 1) == day;
    return ChoiceChip(
      label: Text(names[day - 1]),
      selected: selected,
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
          color: selected ? Colors.white : AppTheme.textSecondary,
          fontSize: 12),
      onSelected: (_) =>
          setState(() => _schedule = _schedule.copyWith(dayOfWeek: day)),
    );
  }

  Widget _channelChip(String label, String value) {
    final selected = _schedule.channels.contains(value);
    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppTheme.primaryColor,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
          color: selected ? Colors.white : AppTheme.textSecondary,
          fontSize: 12),
      onSelected: (v) => setState(() {
        final ch = List<String>.from(_schedule.channels);
        if (v) {
          if (!ch.contains(value)) ch.add(value);
        } else {
          ch.remove(value);
        }
        if (ch.isEmpty) ch.add(value);
        _schedule = _schedule.copyWith(channels: ch);
      }),
    );
  }
}
