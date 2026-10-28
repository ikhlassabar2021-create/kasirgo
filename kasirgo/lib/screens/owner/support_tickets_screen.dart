import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/support_ticket_service.dart';
import '../../widgets/common/centennial_background.dart';
import '../../widgets/common/app_close_button.dart';

/// Tiket Bantuan: owner/staf membuat tiket ke superadmin KasirGo dan
/// membalas percakapan sampai tiket ditutup.
class SupportTicketsScreen extends ConsumerStatefulWidget {
  const SupportTicketsScreen({super.key, this.embedded = false});

  /// true = dipakai sebagai tab di layar Bantuan (tanpa AppBar sendiri).
  final bool embedded;

  @override
  ConsumerState<SupportTicketsScreen> createState() =>
      _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends ConsumerState<SupportTicketsScreen> {
  final _service = SupportTicketService();
  List<SupportTicket> _tickets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null || outletId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (!silent && mounted) setState(() => _loading = true);
    final list = await _service.listTickets(outletId);
    if (!mounted) return;
    setState(() {
      _tickets = list;
      _loading = false;
    });
  }

  Future<void> _createTicket() async {
    final result = await showModalBottomSheet<_NewTicketDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewTicketSheet(),
    );
    if (result == null) return;
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null) return;
    final created = await _service.createTicket(
      outletId: outletId,
      subject: result.subject,
      description: result.description,
    );
    if (!mounted) return;
    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membuat tiket. Coba lagi.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    var failed = 0;
    if (result.files.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mengunggah ${result.files.length} lampiran...'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
      for (final f in result.files) {
        final up = await _service.uploadAttachment(
          outletId: outletId,
          ticketId: created.id,
          bytes: f.bytes,
          fileName: f.name,
          mimeType: f.mime,
        );
        if (up == null) failed++;
      }
    }
    await _load(silent: true);
    if (!mounted) return;
    if (failed > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$failed lampiran gagal diunggah.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
    _openTicket(created);
  }

  Future<void> _openTicket(SupportTicket ticket) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SupportTicketDetailScreen(ticket: ticket),
      ),
    );
    if (changed == true) await _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isOwner = user?.role == 'owner';
    final open = _tickets.where((t) => t.status != 'close').length;

    return Scaffold(
      backgroundColor: widget.embedded
          ? Colors.transparent
          : AppTheme.backgroundColor,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: AppTheme.surfaceColor,
              elevation: 0,
              scrolledUnderElevation: 0,
              shape: const Border(
                bottom: BorderSide(color: AppTheme.borderColor),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tiket Bantuan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    open > 0
                        ? '$open tiket masih berjalan'
                        : 'Tim KasirGo siap membantu',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Muat ulang',
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: AppTheme.primaryColor,
                  ),
                  onPressed: () => _load(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'support-new-ticket',
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        onPressed: _createTicket,
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('Tiket Baru'),
      ),
      body: CentennialBackground(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              )
            : _tickets.isEmpty
            ? _emptyState()
            : RefreshIndicator(
                onRefresh: _load,
                color: AppTheme.primaryColor,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: _tickets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ticketCard(_tickets[i]),
                ),
              ),
      ),
      bottomNavigationBar: isOwner
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Hanya owner yang dapat menutup tiket.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                size: 40,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada tiket',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tulis pertanyaan, kendala, atau permintaan bantuan Anda. '
              'Tim KasirGo akan membalas di sini.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _createTicket,
              icon: const Icon(Icons.add_comment_rounded, size: 18),
              label: const Text('Buat Tiket Pertama'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ticketCard(SupportTicket ticket) {
    final color = _statusColor(ticket.status);
    return Material(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openTicket(ticket),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.45)),
                    ),
                    child: Text(
                      ticket.statusLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _timeAgo(ticket.updatedAt ?? ticket.createdAt),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                ticket.subject,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if ((ticket.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  ticket.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${ticket.replyCount} balasan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Buka',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'proses':
        return AppTheme.warningColor;
      case 'close':
        return AppTheme.successColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}

class SupportTicketDetailScreen extends ConsumerStatefulWidget {
  const SupportTicketDetailScreen({super.key, required this.ticket});

  final SupportTicket ticket;

  @override
  ConsumerState<SupportTicketDetailScreen> createState() =>
      _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState
    extends ConsumerState<SupportTicketDetailScreen> {
  final _service = SupportTicketService();
  final _controller = TextEditingController();
  List<SupportTicketReply> _replies = [];
  List<SupportAttachment> _attachments = [];
  final Map<String, String> _signed = {};
  final List<_PickedFile> _pending = [];
  late SupportTicket _ticket;
  bool _loading = true;
  bool _sending = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final replies = await _service.listReplies(_ticket.id);
    final outlets = ref.read(currentUserProvider)?.outletId;
    if (outlets != null) {
      final fresh = await _service.listTickets(outlets);
      final match = fresh.where((t) => t.id == _ticket.id);
      if (match.isNotEmpty) _ticket = match.first;
    }
    final atts = await _service.listAttachments(_ticket.id);
    final signed = <String, String>{};
    for (final a in atts) {
      final url = await _service.createSignedUrl(a.storagePath);
      if (url != null) signed[a.id] = url;
    }
    if (!mounted) return;
    setState(() {
      _replies = replies;
      _attachments = atts;
      _signed
        ..clear()
        ..addAll(signed);
      _loading = false;
    });
  }

  Future<void> _pickAttachments() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.any,
      );
      if (res == null || res.files.isEmpty) return;
      final accepted = <_PickedFile>[];
      String? error;
      for (final f in res.files) {
        if (f.bytes == null) continue;
        if (f.bytes!.length > SupportTicketService.maxAttachmentBytes) {
          error = '${f.name} lebih dari 10 MB dan dilewati.';
          continue;
        }
        if (_pending.length + accepted.length >= 3) {
          error = 'Maksimal 3 lampiran per pesan.';
          break;
        }
        accepted.add(
          _PickedFile(
            name: f.name,
            bytes: f.bytes!,
            mime: _mimeTypeFor(f.name),
          ),
        );
      }
      if (!mounted) return;
      setState(() => _pending.addAll(accepted));
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak bisa membuka pemilih berkas.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if ((text.isEmpty && _pending.isEmpty) || _sending) return;
    final user = ref.read(currentUserProvider);
    final isOwner = user?.role == 'owner';
    final outletId = user?.outletId;
    if (outletId == null) return;
    final files = List<_PickedFile>.from(_pending);
    setState(() => _sending = true);
    final reply = await _service.reply(
      ticketId: _ticket.id,
      body: text.isEmpty ? 'Lampiran' : text,
      asOwner: isOwner,
    );
    if (!mounted) return;
    if (reply == null) {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengirim balasan.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    var failed = 0;
    for (final f in files) {
      final up = await _service.uploadAttachment(
        outletId: outletId,
        ticketId: _ticket.id,
        replyId: reply.id,
        bytes: f.bytes,
        fileName: f.name,
        mimeType: f.mime,
      );
      if (up == null) failed++;
    }
    if (!mounted) return;
    setState(() {
      _sending = false;
      _pending.clear();
    });
    _controller.clear();
    _changed = true;
    await _load();
    if (mounted && failed > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$failed lampiran gagal diunggah.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _setStatus(String status) async {
    final ok = await _service.setStatus(_ticket.id, status);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memperbarui status tiket.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    _changed = true;
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'close'
                ? 'Tiket ditutup. Terima kasih!'
                : 'Tiket dibuka kembali.',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(currentUserProvider)?.role == 'owner';
    final color = _ticket.isClosed
        ? AppTheme.successColor
        : _ticket.status == 'proses'
        ? AppTheme.warningColor
        : AppTheme.primaryColor;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.surfaceColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          shape: const Border(bottom: BorderSide(color: AppTheme.borderColor)),
          title: Text(
            'Detail Tiket',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          actions: [
            if (isOwner)
              _ticket.isClosed
                  ? TextButton.icon(
                      onPressed: () => _setStatus('open'),
                      icon: const Icon(Icons.lock_open_rounded, size: 16),
                      label: const Text('Buka'),
                    )
                  : TextButton.icon(
                      onPressed: () => _setStatus('close'),
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 16,
                      ),
                      label: const Text('Tutup'),
                    ),
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                border: const Border(
                  bottom: BorderSide(color: AppTheme.borderColor),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _ticket.statusLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(_ticket.createdAt),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _ticket.subject,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if ((_ticket.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _ticket.description!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        height: 1.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  _attachmentBlock(
                    _attachments
                        .where((a) => a.replyId == null)
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : _replies.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada balasan. Tim KasirGo akan segera membalas.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _replies.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _bubble(_replies[i]),
                    ),
            ),
            if (!_ticket.isClosed)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceColor,
                  border: Border(top: BorderSide(color: AppTheme.borderColor)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_pending.isNotEmpty) _pendingStrip(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Lampiran',
                          onPressed: _sending ? null : _pickAttachments,
                          icon: const Icon(
                            Icons.attach_file_rounded,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.newline,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Tulis balasan...',
                              filled: true,
                              fillColor: AppTheme.backgroundColor,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppTheme.borderColor,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppTheme.borderColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: FilledButton(
                            onPressed: _sending ? null : _send,
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                color: AppTheme.surfaceColor,
                child: Text(
                  isOwner
                      ? 'Tiket sudah ditutup. Tekan "Buka" bila masih perlu bantuan.'
                      : 'Tiket sudah ditutup.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(SupportTicketReply reply) {
    final mine = !reply.isPlatform;
    final color = reply.isPlatform
        ? AppTheme.primaryColor
        : AppTheme.successColor;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(
            color: reply.isPlatform
                ? AppTheme.surfaceColor
                : AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 4),
              bottomRight: Radius.circular(mine ? 4 : 14),
            ),
            border: Border.all(
              color: reply.isPlatform
                  ? AppTheme.borderColor
                  : AppTheme.primaryColor.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reply.isPlatform
                    ? 'Tim KasirGo'
                    : reply.authorRole == 'owner'
                    ? 'Owner'
                    : 'Staf',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                reply.body,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  height: 1.45,
                  color: AppTheme.textPrimary,
                ),
              ),
              _attachmentBlock(
                _attachments
                    .where((a) => a.replyId == reply.id)
                    .toList(growable: false),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(reply.createdAt),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pendingStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _pending
            .map(
              (f) => Chip(
                visualDensity: VisualDensity.compact,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
                side: const BorderSide(color: AppTheme.borderColor),
                avatar: Icon(
                  _mimeTypeFor(f.name).startsWith('image/')
                      ? Icons.image_rounded
                      : Icons.insert_drive_file_rounded,
                  size: 15,
                  color: AppTheme.primaryColor,
                ),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                onDeleted: _sending
                    ? null
                    : () => setState(() => _pending.remove(f)),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _attachmentBlock(List<SupportAttachment> atts) {
    if (atts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: atts.map(_attachmentTile).toList(growable: false),
      ),
    );
  }

  Widget _attachmentTile(SupportAttachment a) {
    final url = _signed[a.id];
    if (a.isImage) {
      return GestureDetector(
        onTap: () => _openAttachment(a),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 148,
            height: 108,
            color: AppTheme.backgroundColor,
            child: url == null
                ? const Icon(
                    Icons.image_outlined,
                    color: AppTheme.textSecondary,
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: AppTheme.textSecondary,
                    ),
                  ),
          ),
        ),
      );
    }
    return InkWell(
      onTap: () => _openAttachment(a),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 214,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Icon(
              a.extension == 'PDF'
                  ? Icons.picture_as_pdf_rounded
                  : Icons.insert_drive_file_rounded,
              size: 20,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '${a.extension} - ${a.sizeLabel}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAttachment(SupportAttachment a) async {
    var url = _signed[a.id];
    url ??= await _service.createSignedUrl(a.storagePath);
    if (!mounted) return;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lampiran tidak bisa dibuka. Coba muat ulang.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!a.isImage) {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada aplikasi untuk membuka berkas ini.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: AppTheme.surfaceColor,
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
            maxWidth: 520,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InteractiveViewer(
                maxScale: 4,
                child: Image.network(
                  url!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(28),
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppTheme.borderColor)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          launchUrl(uri, mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_new_rounded, size: 15),
                      label: const Text('Buka'),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _NewTicketSheet extends StatefulWidget {
  const _NewTicketSheet();

  @override
  State<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends State<_NewTicketSheet> {
  final _subject = TextEditingController();
  final _desc = TextEditingController();
  final List<_PickedFile> _files = [];
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.any,
      );
      if (res == null || res.files.isEmpty) return;
      final accepted = <_PickedFile>[];
      String? error;
      for (final f in res.files) {
        if (f.bytes == null) continue;
        if (f.bytes!.length > SupportTicketService.maxAttachmentBytes) {
          error = '${f.name} lebih dari 10 MB dan dilewati.';
          continue;
        }
        if (_files.length + accepted.length >= 3) {
          error = 'Maksimal 3 lampiran.';
          break;
        }
        accepted.add(
          _PickedFile(
            name: f.name,
            bytes: f.bytes!,
            mime: _mimeTypeFor(f.name),
          ),
        );
      }
      if (!mounted) return;
      setState(() => _files.addAll(accepted));
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak bisa membuka pemilih berkas.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _submit() {
    if (_subject.text.trim().length < 4) {
      setState(() => _error = 'Judul minimal 4 karakter.');
      return;
    }
    final desc = _desc.text.trim();
    Navigator.pop(
      context,
      _NewTicketDraft(
        subject: _subject.text.trim(),
        description: desc.isEmpty ? null : desc,
        files: List.unmodifiable(_files),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tiket Bantuan Baru',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  AppCloseButton(onTap: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subject,
                maxLength: 120,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Judul / topik',
                  hintText: 'Mis. QRIS tidak muncul saat pembayaran',
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _desc,
                minLines: 3,
                maxLines: 6,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Jelaskan kendala (opsional)',
                  hintText:
                      'Sebutkan menu yang dipakai, pesan error, dan '
                      'kapan kejadiannya.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _files.length >= 3 ? null : _pick,
                    icon: const Icon(Icons.attach_file_rounded, size: 17),
                    label: const Text('Lampiran'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gambar/berkas, maks 3 x 10 MB',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (_files.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _files
                        .map(
                          (f) => Chip(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: AppTheme.primaryColor.withValues(
                              alpha: 0.08,
                            ),
                            side: const BorderSide(color: AppTheme.borderColor),
                            avatar: Icon(
                              f.mime.startsWith('image/')
                                  ? Icons.image_rounded
                                  : Icons.insert_drive_file_rounded,
                              size: 15,
                              color: AppTheme.primaryColor,
                            ),
                            label: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 130),
                              child: Text(
                                f.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            onDeleted: () => setState(() => _files.remove(f)),
                          ),
                        )
                        .toList(),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.errorColor,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Kirim Tiket'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickedFile {
  const _PickedFile({
    required this.name,
    required this.bytes,
    required this.mime,
  });

  final String name;
  final Uint8List bytes;
  final String mime;
}

class _NewTicketDraft {
  const _NewTicketDraft({
    required this.subject,
    required this.description,
    required this.files,
  });

  final String subject;
  final String? description;
  final List<_PickedFile> files;
}

String _mimeTypeFor(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'heic':
      return 'image/heic';
    case 'pdf':
      return 'application/pdf';
    default:
      return 'application/octet-stream';
  }
}
