import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/support_ticket_service.dart';
import '../../widgets/common/centennial_background.dart';
import '../../widgets/common/app_close_button.dart';

/// Tiket Bantuan: owner/staf membuat tiket ke superadmin KasirGo dan
/// membalas percakapan sampai tiket ditutup.
class SupportTicketsScreen extends ConsumerStatefulWidget {
  const SupportTicketsScreen({super.key});

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
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewTicketSheet(),
    );
    if (result == null) return;
    final outletId = ref.read(currentUserProvider)?.outletId;
    if (outletId == null) return;
    final created = await _service.createTicket(
      outletId: outletId,
      subject: result['subject'] ?? '',
      description: result['description'],
    );
    if (!mounted) return;
    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gagal membuat tiket. Coba lagi.'),
        backgroundColor: AppTheme.errorColor,
      ));
      return;
    }
    await _load(silent: true);
    if (!mounted) return;
    _openTicket(created);
  }

  Future<void> _openTicket(SupportTicket ticket) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SupportTicketDetailScreen(ticket: ticket)),
    );
    if (changed == true) await _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isOwner = user?.role == 'owner';
    final open = _tickets.where((t) => t.status != 'close').length;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: AppTheme.borderColor)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tiket Bantuan',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            Text(
              open > 0
                  ? '$open tiket masih berjalan'
                  : 'Tim KasirGo siap membantu',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
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
                child: CircularProgressIndicator(color: AppTheme.primaryColor))
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
                      fontSize: 10.5, color: AppTheme.textSecondary),
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
              child: const Icon(Icons.support_agent_rounded,
                  size: 40, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            Text('Belum ada tiket',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            Text(
              'Tulis pertanyaan, kendala, atau permintaan bantuan Anda. '
              'Tim KasirGo akan membalas di sini.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5, color: AppTheme.textSecondary, height: 1.5),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.45)),
                    ),
                    child: Text(ticket.statusLabel,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: color)),
                  ),
                  const Spacer(),
                  Text(_timeAgo(ticket.updatedAt ?? ticket.createdAt),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
              const SizedBox(height: 8),
              Text(ticket.subject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              if ((ticket.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(ticket.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 5),
                  Text('${ticket.replyCount} balasan',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: AppTheme.textSecondary)),
                  const Spacer(),
                  Text('Buka',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor)),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppTheme.primaryColor),
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
    if (!mounted) return;
    setState(() {
      _replies = replies;
      _loading = false;
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final isOwner = ref.read(currentUserProvider)?.role == 'owner';
    final ok = await _service.reply(
        ticketId: _ticket.id, body: text, asOwner: isOwner);
    if (!mounted) return;
    setState(() => _sending = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gagal mengirim balasan.'),
        backgroundColor: AppTheme.errorColor,
      ));
      return;
    }
    _controller.clear();
    _changed = true;
    await _load();
  }

  Future<void> _setStatus(String status) async {
    final ok = await _service.setStatus(_ticket.id, status);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gagal memperbarui status tiket.'),
        backgroundColor: AppTheme.errorColor,
      ));
      return;
    }
    _changed = true;
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'close'
            ? 'Tiket ditutup. Terima kasih!'
            : 'Tiket dibuka kembali.'),
        backgroundColor: AppTheme.successColor,
      ));
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
          title: Text('Detail Tiket',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
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
                      icon: const Icon(Icons.check_circle_outline_rounded,
                          size: 16),
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
                    bottom: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_ticket.statusLabel,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: color)),
                      ),
                      const Spacer(),
                      Text(_formatDate(_ticket.createdAt),
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_ticket.subject,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary)),
                  if ((_ticket.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(_ticket.description!,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            height: 1.5,
                            color: AppTheme.textSecondary)),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryColor))
                  : _replies.isEmpty
                      ? Center(
                          child: Text(
                            'Belum ada balasan. Tim KasirGo akan segera membalas.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5, color: AppTheme.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _replies.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, i) =>
                              _bubble(_replies[i]),
                        ),
            ),
            if (!_ticket.isClosed)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceColor,
                  border: Border(top: BorderSide(color: AppTheme.borderColor)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Tulis balasan...',
                          filled: true,
                          fillColor: AppTheme.backgroundColor,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppTheme.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppTheme.borderColor),
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
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, size: 20),
                      ),
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
                      fontSize: 11.5, color: AppTheme.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(SupportTicketReply reply) {
    final mine = !reply.isPlatform;
    final color = reply.isPlatform ? AppTheme.primaryColor : AppTheme.successColor;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78),
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
                    : AppTheme.primaryColor.withValues(alpha: 0.35)),
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
                    color: color),
              ),
              const SizedBox(height: 3),
              Text(reply.body,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      height: 1.45,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              Text(_formatDate(reply.createdAt),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5, color: AppTheme.textSecondary)),
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
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _submit() {
    if (_subject.text.trim().length < 4) {
      setState(() => _error = 'Judul minimal 4 karakter.');
      return;
    }
    Navigator.pop(context, {
      'subject': _subject.text.trim(),
      'description': _desc.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom + 12),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Tiket Bantuan Baru',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary)),
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
                hintText: 'Sebutkan menu yang dipakai, pesan error, dan '
                    'kapan kejadiannya.',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppTheme.errorColor)),
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
    );
  }
}