import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/services/business_doctor_service.dart';
import 'package:kasirgo/services/delegation_service.dart';
import 'package:kasirgo/services/doctor_alert_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _client = SupabaseClient('https://example.supabase.co', 'test-key');

class _FakeDelegation extends DelegationService {
  _FakeDelegation(this.outletItems, this.mineItems) : super(client: _client);
  final List<DoctorDelegation> outletItems;
  final List<DoctorDelegation> mineItems;

  @override
  Future<List<DoctorDelegation>> listForOutlet(
    String outletId, {
    bool onlyOpen = false,
  }) async =>
      outletItems;

  @override
  Future<List<DoctorDelegation>> listMine({bool onlyOpen = true}) async =>
      mineItems;
}

class _FakeDoctor extends BusinessDoctorService {
  _FakeDoctor(this.reprimand) : super(client: _client);
  final Map<String, dynamic>? reprimand;

  @override
  Future<Map<String, dynamic>?> getLatestReprimand(String outletId) async =>
      reprimand;
}

DoctorDelegation _task({
  required String id,
  DateTime? dueAt,
  String status = 'pending',
  String assignedName = 'Kasir Demo',
}) {
  return DoctorDelegation(
    id: id,
    outletId: 'outlet-1',
    title: 'Tugas $id',
    assignedName: assignedName,
    status: status,
    dueAt: dueAt,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('owner: notifikasi tugas terlambat + teguran sekali saja per hari', () async {
    final now = DateTime.now();
    final service = DoctorAlertService(
      delegation: _FakeDelegation([
        _task(id: 'a', dueAt: now.subtract(const Duration(days: 2))),
        _task(id: 'b', dueAt: now.subtract(const Duration(days: 1))),
        _task(id: 'c', dueAt: now.add(const Duration(days: 3))),
        _task(id: 'd', dueAt: now.subtract(const Duration(days: 5)), status: 'selesai'),
      ], const []),
      doctor: _FakeDoctor({'id': 'rx-1', 'title': 'Teguran', 'content': 'Kerjakan'}),
    );

    final first = await service.checkAndNotify(outletId: 'outlet-1');
    expect(first, 2, reason: '1 notifikasi rekap terlambat + 1 teguran');

    final second = await service.checkAndNotify(outletId: 'outlet-1');
    expect(second, 0, reason: 'anti-spam: tidak diulang di hari yang sama');
  });

  test('staf: hanya tugas miliknya yang jatuh tempo/terlambat', () async {
    final now = DateTime.now();
    final service = DoctorAlertService(
      delegation: _FakeDelegation(const [], [
        _task(id: 'x', dueAt: now.subtract(const Duration(hours: 2))),
        _task(id: 'y', dueAt: now.add(const Duration(days: 4))),
        _task(id: 'z', dueAt: now, status: 'dikerjakan'),
      ]),
      doctor: _FakeDoctor(null),
    );

    final shown = await service.checkAndNotify(
      outletId: 'outlet-1',
      userId: 'user-1',
      role: 'cashier',
    );
    expect(shown, 2, reason: 'tugas x (terlambat) + z (jatuh tempo hari ini)');
  });

  test('tugas tanpa tenggat atau sudah ditutup tidak memicu notifikasi', () async {
    final service = DoctorAlertService(
      delegation: _FakeDelegation([
        _task(id: 'no-due'),
        _task(id: 'skipped', dueAt: DateTime.now().subtract(const Duration(days: 3)), status: 'dilewati'),
      ], const []),
      doctor: _FakeDoctor(null),
    );

    expect(await service.checkAndNotify(outletId: 'outlet-1'), 0);
  });
}
