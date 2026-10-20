import 'package:supabase_flutter/supabase_flutter.dart';

/// Satu tugas dari owner yang didelegasikan ke staf outlet.
class DoctorDelegation {
  final String id;
  final String outletId;
  final String title;
  final String body;
  final String category;
  final String source;
  final String? sourceRef;
  final int? stepIndex;
  final String? assignedUserId;
  final String assignedName;
  final String assignedRole;
  final String priority;
  final String status;
  final DateTime? dueAt;
  final DateTime? doneAt;
  final String? doneNote;
  final DateTime? createdAt;

  const DoctorDelegation({
    required this.id,
    required this.outletId,
    required this.title,
    this.body = '',
    this.category = 'lainnya',
    this.source = 'manual',
    this.sourceRef,
    this.stepIndex,
    this.assignedUserId,
    this.assignedName = '',
    this.assignedRole = '',
    this.priority = 'normal',
    this.status = 'pending',
    this.dueAt,
    this.doneAt,
    this.doneNote,
    this.createdAt,
  });

  bool get isDone => status == 'selesai';
  bool get isSkipped => status == 'dilewati';
  bool get isWorking => status == 'dikerjakan';
  bool get isClosed => isDone || isSkipped;

  bool get isOverdue {
    final due = dueAt;
    if (due == null || isClosed) return false;
    return due.isBefore(DateTime.now());
  }

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }

  factory DoctorDelegation.fromMap(Map<String, dynamic> m) {
    return DoctorDelegation(
      id: m['id']?.toString() ?? '',
      outletId: m['outlet_id']?.toString() ?? '',
      title: m['title']?.toString() ?? '',
      body: m['body']?.toString() ?? '',
      category: m['category']?.toString() ?? 'lainnya',
      source: m['source']?.toString() ?? 'manual',
      sourceRef: m['source_ref']?.toString(),
      stepIndex: (m['step_index'] as num?)?.toInt(),
      assignedUserId: m['assigned_user_id']?.toString(),
      assignedName: m['assigned_name']?.toString() ?? '',
      assignedRole: m['assigned_role']?.toString() ?? '',
      priority: m['priority']?.toString() ?? 'normal',
      status: m['status']?.toString() ?? 'pending',
      dueAt: _date(m['due_at']),
      doneAt: _date(m['done_at']),
      doneNote: m['done_note']?.toString(),
      createdAt: _date(m['created_at']),
    );
  }
}

/// Delegasi tugas Dokter Bisnis ke Admin / Kasir / Koki.
class DelegationService {
  DelegationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _columns =
      'id, outlet_id, title, body, category, source, source_ref, step_index, '
      'assigned_user_id, assigned_name, assigned_role, priority, status, '
      'due_at, done_at, done_note, created_at';

  String? get _uid => _client.auth.currentUser?.id;

  /// Daftar staf outlet (Admin/Kasir/Koki) sebagai calon penerima tugas.
  Future<List<Map<String, dynamic>>> staffOptions(String outletId) async {
    try {
      final rows = await _client
          .from('user_roles')
          .select('id, user_id, role, display_name')
          .eq('outlet_id', outletId);
      return (rows as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Semua tugas satu outlet (owner / superadmin).
  Future<List<DoctorDelegation>> listForOutlet(
    String outletId, {
    bool onlyOpen = false,
  }) async {
    try {
      var query = _client
          .from('doctor_delegations')
          .select(_columns)
          .eq('outlet_id', outletId);
      if (onlyOpen) {
        query = query.inFilter('status', ['pending', 'dikerjakan']);
      }
      final rows =
          await query.order('created_at', ascending: false).limit(200);
      return (rows as List)
          .whereType<Map>()
          .map((e) => DoctorDelegation.fromMap(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Tugas milik pengguna yang sedang login (staf).
  Future<List<DoctorDelegation>> listMine({bool onlyOpen = true}) async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      var query =
          _client.from('doctor_delegations').select(_columns).eq(
                'assigned_user_id',
                uid,
              );
      if (onlyOpen) {
        query = query.inFilter('status', ['pending', 'dikerjakan']);
      }
      final rows = await query
          .order('due_at', ascending: true, nullsFirst: false)
          .limit(100);
      return (rows as List)
          .whereType<Map>()
          .map((e) => DoctorDelegation.fromMap(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Buat tugas baru. Kembalikan id bila sukses.
  Future<String?> create({
    required String outletId,
    required String title,
    String? body,
    String category = 'lainnya',
    String source = 'manual',
    String? sourceRef,
    int? stepIndex,
    String? assignedUserId,
    String? assignedName,
    String? assignedRole,
    String priority = 'normal',
    DateTime? dueAt,
  }) async {
    try {
      final row = await _client
          .from('doctor_delegations')
          .insert({
            'outlet_id': outletId,
            'title': title,
            'body': ?body,
            'category': category,
            'source': source,
            'source_ref': ?sourceRef,
            'step_index': ?stepIndex,
            'assigned_user_id': ?assignedUserId,
            'assigned_name': ?assignedName,
            'assigned_role': ?assignedRole,
            'priority': priority,
            'due_at': ?dueAt?.toUtc().toIso8601String(),
            'created_by': _uid,
          })
          .select('id')
          .maybeSingle();
      return row?['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Ubah isi tugas (owner).
  Future<bool> update(
    String id, {
    String? title,
    String? body,
    String? category,
    String? priority,
    String? assignedUserId,
    String? assignedName,
    String? assignedRole,
    DateTime? dueAt,
    bool clearDue = false,
  }) async {
    try {
      final patch = <String, dynamic>{
        'title': ?title,
        'body': ?body,
        'category': ?category,
        'priority': ?priority,
        'assigned_user_id': ?assignedUserId,
        'assigned_name': ?assignedName,
        'assigned_role': ?assignedRole,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (clearDue) {
        patch['due_at'] = null;
      } else if (dueAt != null) {
        patch['due_at'] = dueAt.toUtc().toIso8601String();
      }
      await _client.from('doctor_delegations').update(patch).eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Staf (atau owner) mengubah status tugas lewat RPC aman.
  Future<Map<String, dynamic>> setStatus(
    String id,
    String status, {
    String? note,
  }) async {
    try {
      final res = await _client.rpc('delegation_set_status', params: {
        'p_id': id,
        'p_status': status,
        'p_note': ?note,
      });
      if (res is Map) return res.cast<String, dynamic>();
      return {'ok': true};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _client.from('doctor_delegations').delete().eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ringkasan jumlah tugas per status.
  Future<Map<String, dynamic>> summary(String outletId) async {
    try {
      final res = await _client
          .rpc('delegation_summary', params: {'p_outlet': outletId});
      if (res is Map) return res.cast<String, dynamic>();
    } catch (_) {}
    return const {'total': 0, 'pending': 0, 'dikerjakan': 0, 'selesai': 0, 'terlambat': 0};
  }
}
