import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Model tiket bantuan (tabel `support_tickets`).
class SupportTicket {
  final String id;
  final String outletId;
  final String? createdBy;
  final String subject;
  final String? description;
  final String status; // open | proses | close
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? closedAt;
  final int replyCount;

  const SupportTicket({
    required this.id,
    required this.outletId,
    this.createdBy,
    required this.subject,
    this.description,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.closedAt,
    this.replyCount = 0,
  });

  static DateTime? _parse(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  factory SupportTicket.fromMap(Map<String, dynamic> map) {
    final replies = map['support_ticket_replies'];
    return SupportTicket(
      id: map['id']?.toString() ?? '',
      outletId: map['outlet_id']?.toString() ?? '',
      createdBy: map['created_by']?.toString(),
      subject: map['subject']?.toString() ?? '',
      description: map['description']?.toString(),
      status: map['status']?.toString() ?? 'open',
      createdAt: _parse(map['created_at']) ?? DateTime.now(),
      updatedAt: _parse(map['updated_at']),
      closedAt: _parse(map['closed_at']),
      replyCount: replies is List ? replies.length : 0,
    );
  }

  bool get isClosed => status == 'close';

  String get statusLabel {
    switch (status) {
      case 'proses':
        return 'Diproses';
      case 'close':
        return 'Selesai';
      default:
        return 'Menunggu';
    }
  }
}

/// Balasan tiket.
class SupportTicketReply {
  final String id;
  final String ticketId;
  final String? authorUid;
  final String authorRole; // owner | staf | superadmin
  final String body;
  final DateTime createdAt;

  const SupportTicketReply({
    required this.id,
    required this.ticketId,
    this.authorUid,
    required this.authorRole,
    required this.body,
    required this.createdAt,
  });

  factory SupportTicketReply.fromMap(Map<String, dynamic> map) =>
      SupportTicketReply(
        id: map['id']?.toString() ?? '',
        ticketId: map['ticket_id']?.toString() ?? '',
        authorUid: map['author_uid']?.toString(),
        authorRole: map['author_role']?.toString() ?? 'staf',
        body: map['body']?.toString() ?? '',
        createdAt:
            DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
            DateTime.now(),
      );

  bool get isPlatform => authorRole == 'superadmin';
}

/// Servis tiket bantuan ke superadmin (tabel `support_tickets` +
/// `support_ticket_replies`, RLS outlet member / superadmin).
class SupportTicketService {
  final SupabaseClient _client;
  SupportTicketService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<List<SupportTicket>> listTickets(String outletId) async {
    try {
      final res = await _client
          .from('support_tickets')
          .select('*, support_ticket_replies(id)')
          .eq('outlet_id', outletId)
          .order('updated_at', ascending: false)
          .limit(100);
      return (res as List)
          .map(
            (e) => SupportTicket.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      debugPrint('SupportTicketService.listTickets error: $e');
      return [];
    }
  }

  Future<SupportTicket?> createTicket({
    required String outletId,
    required String subject,
    String? description,
  }) async {
    try {
      final user = _client.auth.currentUser;
      final res = await _client
          .from('support_tickets')
          .insert({
            'outlet_id': outletId,
            'created_by': user?.id,
            'subject': subject.trim(),
            'description': (description ?? '').trim().isEmpty
                ? null
                : description!.trim(),
            'status': 'open',
          })
          .select()
          .single();
      return SupportTicket.fromMap(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('SupportTicketService.createTicket error: $e');
      return null;
    }
  }

  Future<List<SupportTicketReply>> listReplies(String ticketId) async {
    try {
      final res = await _client
          .from('support_ticket_replies')
          .select()
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: true);
      return (res as List)
          .map(
            (e) =>
                SupportTicketReply.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      debugPrint('SupportTicketService.listReplies error: $e');
      return [];
    }
  }

  /// Kirim balasan; mengembalikan baris balasan (id dipakai untuk lampiran),
  /// atau null saat gagal. Balasan owner membuka kembali tiket selesai.
  Future<SupportTicketReply?> reply({
    required String ticketId,
    required String body,
    bool asOwner = false,
  }) async {
    final text = body.trim();
    if (text.isEmpty) return null;
    try {
      final user = _client.auth.currentUser;
      final res = await _client
          .from('support_ticket_replies')
          .insert({
            'ticket_id': ticketId,
            'author_uid': user?.id,
            'author_role': asOwner ? 'owner' : 'staf',
            'body': text,
          })
          .select()
          .single();
      // Balasan owner membuka kembali tiket yang sudah selesai.
      final current = await _client
          .from('support_tickets')
          .select('status')
          .eq('id', ticketId)
          .maybeSingle();
      if (current != null && current['status'] == 'close' && asOwner) {
        await _client
            .from('support_tickets')
            .update({'status': 'open'})
            .eq('id', ticketId);
      }
      return SupportTicketReply.fromMap(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('SupportTicketService.reply error: $e');
      return null;
    }
  }

  Future<bool> setStatus(String ticketId, String status) async {
    try {
      await _client
          .from('support_tickets')
          .update({'status': status})
          .eq('id', ticketId);
      return true;
    } catch (e) {
      debugPrint('SupportTicketService.setStatus error: $e');
      return false;
    }
  }

  /// Hapus tiket (dipakai superadmin; owner hanya menutup tiket).
  Future<bool> deleteTicket(String ticketId) async {
    try {
      await _client.from('support_tickets').delete().eq('id', ticketId);
      return true;
    } catch (e) {
      debugPrint('SupportTicketService.deleteTicket error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------
  // Lampiran tiket (gambar/file) di bucket privat `support-attachments`.
  // ---------------------------------------------------------------------

  static const attachmentBucket = 'support-attachments';
  static const maxAttachmentBytes = 10 * 1024 * 1024;

  Future<List<SupportAttachment>> listAttachments(String ticketId) async {
    try {
      final res = await _client
          .from('support_ticket_attachments')
          .select()
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: true);
      return (res as List)
          .map(
            (e) =>
                SupportAttachment.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      debugPrint('SupportTicketService.listAttachments error: $e');
      return [];
    }
  }

  Future<String?> createSignedUrl(
    String storagePath, {
    int expiresIn = 3600,
  }) async {
    try {
      return await _client.storage
          .from(attachmentBucket)
          .createSignedUrl(storagePath, expiresIn);
    } catch (e) {
      debugPrint('SupportTicketService.createSignedUrl error: $e');
      return null;
    }
  }

  Future<SupportAttachment?> uploadAttachment({
    required String outletId,
    required String ticketId,
    String? replyId,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    if (bytes.isEmpty) return null;
    if (bytes.length > maxAttachmentBytes) return null;
    final safeName = _safeFileName(fileName);
    final mime = (mimeType == null || mimeType.isEmpty)
        ? _mimeFromName(safeName)
        : mimeType;
    final path =
        '$outletId/$ticketId/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    try {
      await _client.storage
          .from(attachmentBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mime, upsert: false),
          );
      final res = await _client
          .from('support_ticket_attachments')
          .insert({
            'ticket_id': ticketId,
            'reply_id': replyId,
            'outlet_id': outletId,
            'uploaded_by': _client.auth.currentUser?.id,
            'file_name': fileName,
            'mime_type': mime,
            'size_bytes': bytes.length,
            'storage_path': path,
          })
          .select()
          .single();
      return SupportAttachment.fromMap(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('SupportTicketService.uploadAttachment error: $e');
      return null;
    }
  }

  Future<bool> deleteAttachment(SupportAttachment attachment) async {
    try {
      await _client.storage.from(attachmentBucket).remove([
        attachment.storagePath,
      ]);
    } catch (e) {
      debugPrint('SupportTicketService.deleteAttachment storage error: $e');
    }
    try {
      await _client
          .from('support_ticket_attachments')
          .delete()
          .eq('id', attachment.id);
      return true;
    } catch (e) {
      debugPrint('SupportTicketService.deleteAttachment error: $e');
      return false;
    }
  }

  static String _safeFileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (cleaned.isEmpty) return 'lampiran';
    return cleaned.length > 90
        ? cleaned.substring(cleaned.length - 90)
        : cleaned;
  }

  static String _mimeFromName(String name) {
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
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'csv':
        return 'text/csv';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}

/// Lampiran tiket (gambar atau file) di bucket privat.
class SupportAttachment {
  final String id;
  final String ticketId;
  final String? replyId;
  final String fileName;
  final String? mimeType;
  final int sizeBytes;
  final String storagePath;
  final DateTime createdAt;

  const SupportAttachment({
    required this.id,
    required this.ticketId,
    required this.replyId,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.storagePath,
    required this.createdAt,
  });

  factory SupportAttachment.fromMap(Map<String, dynamic> map) =>
      SupportAttachment(
        id: map['id']?.toString() ?? '',
        ticketId: map['ticket_id']?.toString() ?? '',
        replyId: map['reply_id']?.toString(),
        fileName: map['file_name']?.toString() ?? 'lampiran',
        mimeType: map['mime_type']?.toString(),
        sizeBytes: (map['size_bytes'] as num?)?.toInt() ?? 0,
        storagePath: map['storage_path']?.toString() ?? '',
        createdAt:
            DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
            DateTime.now(),
      );

  bool get isImage => (mimeType ?? '').startsWith('image/');

  String get extension {
    final n = fileName;
    return n.contains('.') ? n.split('.').last.toUpperCase() : 'FILE';
  }

  String get sizeLabel {
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (sizeBytes >= 1024) {
      return '${(sizeBytes / 1024).round()} KB';
    }
    return '$sizeBytes B';
  }
}
