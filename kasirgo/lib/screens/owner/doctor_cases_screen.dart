import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/business_doctor_service.dart';
import '../../widgets/common/centennial_background.dart';
import 'business_doctor_screen.dart';

class DoctorCasesScreen extends ConsumerStatefulWidget {
  const DoctorCasesScreen({super.key, this.service});

  final BusinessDoctorService? service;

  @override
  ConsumerState<DoctorCasesScreen> createState() => _DoctorCasesScreenState();
}

class _DoctorCasesScreenState extends ConsumerState<DoctorCasesScreen> {
  late final BusinessDoctorService _service =
      widget.service ?? BusinessDoctorService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _cases = const [];
  List<Map<String, dynamic>> _memories = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Outlet tidak ditemukan.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cases = await _service.listConversations(outletId);
      final memories = await _service.listMemories(outletId);
      if (!mounted) return;
      setState(() {
        _cases = cases;
        _memories = memories;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Riwayat Kasus',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: CentennialBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppTheme.formMaxWidth),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard(
            child: Column(
              children: [
                const Icon(Icons.cloud_off_rounded,
                    color: AppTheme.errorColor, size: 32),
                const SizedBox(height: 8),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                TextButton(onPressed: _load, child: const Text('Coba lagi')),
              ],
            ),
          ),
        ],
      );
    }
    if (_cases.isEmpty && _memories.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard(
            child: Column(
              children: [
                const Icon(Icons.history_rounded,
                    color: AppTheme.textSecondary, size: 32),
                const SizedBox(height: 8),
                Text(
                  'Belum ada riwayat. Mulai konsultasi dengan Dokter Bisnis AI.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_cases.isNotEmpty) ...[
          _sectionTitle('Kasus Konsultasi'),
          for (final c in _cases) ...[
            _buildCase(c),
            const SizedBox(height: 10),
          ],
        ],
        if (_memories.isNotEmpty) ...[
          const SizedBox(height: 8),
          _sectionTitle('Catatan Memori'),
          for (final m in _memories) ...[
            _buildMemory(m),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary)),
    );
  }

  Widget _buildCase(Map<String, dynamic> c) {
    final status = c['status']?.toString() ?? 'aktif';
    final level = int.tryParse(c['escalation_level']?.toString() ?? '') ?? 0;
    final phase = c['phase']?.toString() ?? 'A';
    final color = _statusColor(status);
    final updated = _fmtDate(c['updated_at']);
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      onTap: () => _openCase(c['id']?.toString()),
      child: _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    c['title']?.toString() ?? 'Konsultasi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary),
                  ),
                ),
                _badge(_statusLabel(status), color),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.timeline_rounded,
                    size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text('Fase $phase',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppTheme.textSecondary)),
                if (level > 0) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.warning_amber_rounded,
                      size: 14, color: AppTheme.warningColor),
                  const SizedBox(width: 4),
                  Text('Tingkat $level',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppTheme.warningColor)),
                ],
                const Spacer(),
                Text(updated,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemory(Map<String, dynamic> m) {
    final kind = m['kind']?.toString() ?? 'fact';
    final status = m['status']?.toString() ?? 'open';
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _badge(_kindLabel(kind), AppTheme.primaryColor),
              const SizedBox(width: 6),
              _badge(_statusLabel(status), _statusColor(status)),
              const Spacer(),
              Text(_fmtDate(m['created_at']),
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(m['title']?.toString() ?? '-',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          if ((m['content']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              m['content'].toString(),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.shadowSoft,
      ),
      child: child,
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'kasus_bandel':
        return AppTheme.errorColor;
      case 'evaluasi_ulang':
        return AppTheme.warningColor;
      case 'selesai':
      case 'achieved':
        return AppTheme.successColor;
      case 'failed':
        return AppTheme.errorColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'kasus_bandel':
        return 'Kasus Bandel';
      case 'evaluasi_ulang':
        return 'Evaluasi Ulang';
      case 'selesai':
        return 'Selesai';
      case 'achieved':
        return 'Tercapai';
      case 'failed':
        return 'Gagal';
      case 'open':
        return 'Terbuka';
      default:
        return 'Aktif';
    }
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case 'diagnosis':
        return 'Diagnosa';
      case 'prescription':
        return 'Resep';
      case 'lesson':
        return 'Pelajaran';
      case 'result':
        return 'Hasil';
      default:
        return 'Catatan';
    }
  }

  String _fmtDate(dynamic raw) {
    if (raw == null) return '-';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return '-';
    return DateFormat('d MMM yyyy', 'id_ID').format(dt.toLocal());
  }

  Future<void> _openCase(String? conversationId) async {
    if (conversationId == null || conversationId.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BusinessDoctorScreen(conversationId: conversationId),
      ),
    );
    _load();
  }
}
