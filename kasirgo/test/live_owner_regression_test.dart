// Test live terhadap DB production: mereplikasi PERSIS alur aplikasi untuk
// 4 masalah yang dilaporkan owner:
// 1. Buat karyawan baru (EF create_staff + insert employees)
// 2. QR Meja: baca/tambah/hapus outlet_tables
// 3. Entitlement akun tanpa trial (harus hasAccess=false -> gate muncul)
// 4. Keputusan iklan (decide) tanpa consent -> needsConsent
//
// Jalankan: flutter test test/live_owner_regression_test.dart -r expanded
import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/config/supabase_config.dart';
import 'package:kasirgo/models/employee.dart';
import 'package:kasirgo/services/ad_service.dart';
import 'package:kasirgo/services/auth_service.dart';
import 'package:kasirgo/services/supporter_service.dart';
import 'package:kasirgo/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // Tanpa TestWidgetsFlutterBinding agar network & plugin tetap jalan;
  // SharedPreferences cukup di-mock untuk AdService/SupporterService.
  SharedPreferences.setMockInitialValues({});

  final ownerEmail = 'ikhlassabar2021@gmail.com';
  const ownerPassword = 'sabar2021';
  const noTrialEmail = 'ikhlassabar2021+gerobak@gmail.com';
  const outletTokoTest = '229c94d7-ce6d-4be1-98f5-448f600528cc';
  const outletGerobak = 'e545b57c-7ac8-4709-b4d2-db54819610e1';

  test('SETUP: login owner Toko Test', () async {
    final client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
    final res = await client.auth
        .signInWithPassword(email: ownerEmail, password: ownerPassword);
    expect(res.user, isNotNull);
    await client.auth.signOut();
  });

  test('MASALAH 1: alur tambah karyawan (EF + employees insert)', () async {
    final client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
    await client.auth
        .signInWithPassword(email: ownerEmail, password: ownerPassword);

    final svc = SupabaseService(client: client);
    final authService = AuthService(client: client);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final staffEmail = 'ikhlassabar2021+reg$stamp@gmail.com';

    // Langkah yang sama dengan UI: createStaffAccount (EF create_staff).
    final userId = await authService.createStaffAccount(
      email: staffEmail,
      password: 'sabar2021',
      outletId: outletTokoTest,
      role: 'cashier',
      name: 'Regresi Test',
    );
    expect(userId, isNotNull,
        reason: 'createStaffAccount (EF create_staff) gagal');

    // Langkah kedua UI: insert tabel employees.
    final emp = await svc.createEmployee(
      Employee(
        id: '',
        outletId: outletTokoTest,
        userId: userId ?? '',
        name: 'Regresi Test',
        role: 'cashier',
        isActive: true,
      ),
    );
    // Boleh null (fallback lokal di UI), tapi tidak boleh throw.
    // ignore: avoid_print
    print('employees insert -> ${emp == null ? "NULL (fallback lokal)" : "OK"}');
    await client.auth.signOut();
  });

  test('MASALAH 2: QR Meja baca/tambah/hapus sebagai owner', () async {
    final client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
    await client.auth
        .signInWithPassword(email: ownerEmail, password: ownerPassword);
    final svc = SupabaseService(client: client);

    final before = await svc.getOutletTables(outletTokoTest);
    // ignore: avoid_print
    print('meja sebelum: $before');

    final add = await svc.addOutletTableDetailed(outletTokoTest, 'Reg Meja 9');
    expect(add.ok, isTrue, reason: 'addOutletTable gagal: ${add.error}');

    final afterAdd = await svc.getOutletTables(outletTokoTest);
    expect(afterAdd.contains('Reg Meja 9'), isTrue,
        reason: 'meja baru tidak muncul di daftar: $afterAdd');

    final del = await svc.deleteOutletTable(outletTokoTest, 'Reg Meja 9');
    expect(del, isTrue, reason: 'deleteOutletTable gagal');

    final afterDel = await svc.getOutletTables(outletTokoTest);
    expect(afterDel.contains('Reg Meja 9'), isFalse,
        reason: 'meja masih ada setelah delete: $afterDel');
    await client.auth.signOut();
  });

  test('MASALAH 2b: gate qr_table terbuka utk Toko Test (trial aktif)', () async {
    final client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
    await client.auth
        .signInWithPassword(email: ownerEmail, password: ownerPassword);
    final svc = SupporterService(client: client);
    final ent = await svc.getEntitlements(outletTokoTest);
    final gate = await svc.hasFeature(outletTokoTest, 'qr_table');
    // ignore: avoid_print
    print('tokotest: trialActive=${ent.isTrialActive} hasAccess=${ent.hasAccess} '
        'trialDaysLeft=${ent.trialDaysLeft} gateQrTable=$gate');
    expect(gate, isTrue,
        reason: 'gate qr_table harus TERBUKA (layar QR Meja + tombol Tambah '
            'tampil, bukan layar terkunci)');
    await client.auth.signOut();
  });

  test('MASALAH 3: akun tanpa trial -> hasAccess=false', () async {
    final client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
    await client.auth
        .signInWithPassword(email: noTrialEmail, password: ownerPassword);
    final svc = SupporterService(client: client);
    final ent = await svc.getEntitlements(outletGerobak);
    // ignore: avoid_print
    print('gerobak: isSupporter=${ent.isSupporter} '
        'trialActive=${ent.isTrialActive} hasAccess=${ent.hasAccess} '
        'status=${ent.status}');
    expect(ent.hasAccess, isFalse,
        reason: 'akun tanpa trial harus hasAccess=false (gate wajib muncul)');
    final gateQris = await svc.hasFeature(outletGerobak, 'payment_gateway');
    expect(gateQris, isFalse,
        reason: 'QRIS Dinamis harus terkunci utk akun tanpa trial');
    await client.auth.signOut();
  });

  test('MASALAH 4: decide() tanpa consent -> needsConsent=true', () async {
    final client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
    final svc = AdService(client: client);
    final d = await svc.decide(
        outletId: outletTokoTest, isOwner: false, consentGiven: false);
    // ignore: avoid_print
    print('decide(no consent): needsConsent=${d.needsConsent} '
        'showAds=${d.showAds} adFree=${d.adFree}');
    expect(d.needsConsent, isTrue,
        reason: 'tanpa consent harus needsConsent=true (kartu consent tampil)');

    // Setelah "Tolak": slot hilang permanen (bukan prompt berulang).
    await svc.setConsent(false);
    final d2 = await svc.decide(
        outletId: outletTokoTest, isOwner: false, consentGiven: false);
    // ignore: avoid_print
    print('decide(after decline): needsConsent=${d2.needsConsent} '
        'showAds=${d2.showAds} adFree=${d2.adFree}');
    expect(d2.needsConsent, isFalse,
        reason: 'setelah Tolak, kartu consent TIDAK boleh muncul lagi');
    expect(d2.showAds, isFalse,
        reason: 'setelah Tolak, iklan tidak boleh tampil');
    await svc.clearConsent();
  });
}
