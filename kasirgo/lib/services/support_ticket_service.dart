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
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '')
                ?.toLocal() ??
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
          .map((e) =>
              SupportTicket.fromMap(Map<String, dynamic>.from(e as Map)))
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
          .map((e) =>
              SupportTicketReply.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('SupportTicketService.listReplies error: $e');
      return [];
    }
  }

  Future<bool> reply({
    required String ticketId,
    required String body,
    bool asOwner = false,
  }) async {
    final text = body.trim();
    if (text.isEmpty) return false;
    try {
      final user = _client.auth.currentUser;
      await _client.from('support_ticket_replies').insert({
        'ticket_id': ticketId,
        'author_uid': user?.id,
        'author_role': asOwner ? 'owner' : 'staf',
        'body': text,
      });
      // Balasan owner membuka kembali tiket yang sudah selesai.
      final current = await _client
          .from('support_tickets')
          .select('status')
          .eq('id', ticketId)
          .maybeSingle();
      if (current != null && current['status'] == 'close' && asOwner) {
        await _client
            .from('support_tickets')
            .update({'status': 'open'}).eq('id', ticketId);
      }
      return true;
    } catch (e) {
      debugPrint('SupportTicketService.reply error: $e');
      return false;
    }
  }

  Future<bool> setStatus(String ticketId, String status) async {
    try {
      await _client
          .from('support_tickets')
          .update({'status': status}).eq('id', ticketId);
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
}