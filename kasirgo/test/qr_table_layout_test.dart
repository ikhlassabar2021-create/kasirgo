import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/config/app_theme.dart';
import 'package:kasirgo/providers/auth_provider.dart';
import 'package:kasirgo/screens/owner/qr_table_screen.dart';
import 'package:kasirgo/services/auth_service.dart';

class _FakeAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  testWidgets('QrTableScreen renders form tanpa error layout', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(_FakeAuthService()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const QrTableScreen(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Manajemen QR Meja'), findsOneWidget);
    expect(find.text('Nama / Nomor Meja Baru'), findsOneWidget);
    expect(find.text('Tambah'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
