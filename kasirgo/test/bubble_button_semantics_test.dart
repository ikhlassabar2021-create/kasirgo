import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/config/app_theme.dart';
import 'package:kasirgo/widgets/common/bubble_glass.dart';

Widget _app(List<Widget> actions) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, _) => Container(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('QA Kasir'),
                const Text('#ORD123'),
                const Text('Rp 10.000'),
                const SizedBox(height: 12),
                ...actions,
              ],
            ),
          ),
        ),
      ),
    );

Widget _btn(String label) => SizedBox(
      height: 44,
      child: BubbleButton(onPressed: () {}, child: Text(label)),
    );

List<SemanticsData> _nodes(WidgetTester tester) {
  final out = <SemanticsData>[];
  void walk(SemanticsNode node) {
    out.add(node.getSemanticsData());
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  // ignore: deprecated_member_use
  final root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
  if (root != null) walk(root);
  return out;
}

void main() {
  testWidgets('tombol tunggal dalam kartu tetap node terpisah', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app([
      Row(children: [Expanded(child: _btn('Selesai'))]),
    ]));
    await tester.pumpAndSettle();

    final nodes = _nodes(tester);
    final buttons = nodes.where((n) => n.flagsCollection.isButton).toList();

    expect(buttons, hasLength(1));
    expect(buttons.single.label, 'Selesai');
    expect(buttons.single.label.contains('QA Kasir'), isFalse);
    expect(buttons.single.flagsCollection.isEnabled, Tristate.isTrue);
    handle.dispose();
  });

  testWidgets('dua tombol dalam kartu tetap node terpisah', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app([
      Row(children: [
        Expanded(child: _btn('Pembayaran Valid & Proses')),
        const SizedBox(width: 8),
        Expanded(child: _btn('Tolak / Belum Masuk')),
      ]),
    ]));
    await tester.pumpAndSettle();

    final buttons = _nodes(tester)
        .where((n) => n.flagsCollection.isButton)
        .map((n) => n.label)
        .toList();

    expect(buttons, hasLength(2));
    expect(buttons, containsAll(<String>[
      'Pembayaran Valid & Proses',
      'Tolak / Belum Masuk',
    ]));
    handle.dispose();
  });

  testWidgets('tombol nonaktif melaporkan enabled=false', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app([
      Row(children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: const BubbleButton(onPressed: null, child: Text('Selesai')),
          ),
        ),
      ]),
    ]));
    await tester.pumpAndSettle();

    final buttons =
        _nodes(tester).where((n) => n.flagsCollection.isButton).toList();

    expect(buttons, hasLength(1));
    expect(buttons.single.label, 'Selesai');
    expect(buttons.single.flagsCollection.isEnabled, Tristate.isFalse);
    handle.dispose();
  });
}
