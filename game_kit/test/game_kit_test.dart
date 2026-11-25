import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';

void main() {
  setUp(() => KitTheme.useGoogleFonts = false);

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('die tumbles on a new roll id and settles', (tester) async {
    int taps = 0;
    Widget die(int value, int id) =>
        wrap(DieView(value: value, rollId: id, color: KitColors.coral, enabled: true, onTap: () => taps++));
    await tester.pumpWidget(die(6, 0));
    await tester.tap(find.byType(DieView));
    expect(taps, 1);
    await tester.pumpWidget(die(3, 1));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(DieView), findsOneWidget);
  });

  testWidgets('pod shows name and highlights when active', (tester) async {
    await tester.pumpWidget(wrap(const SizedBox(
      width: 200,
      child: PlayerPod(name: 'Asha', color: KitColors.teal, active: true, timerFraction: 0.5, homeCount: 2),
    )));
    expect(find.text('Asha'), findsOneWidget);
  });

  testWidgets('result view lists ranks and actions', (tester) async {
    await tester.pumpWidget(wrap(SizedBox(
      width: 400,
      height: 800,
      child: ResultView(
        title: 'Asha wins!',
        reduceMotion: true,
        rows: const [
          ResultRowData(rank: 1, name: 'Asha', color: KitColors.teal, detail: '3 captures'),
          ResultRowData(rank: 2, name: 'Ben', color: KitColors.coral),
        ],
        actions: [GoldButton(label: 'Rematch', onPressed: () {})],
      ),
    )));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Asha wins!'), findsOneWidget);
    expect(find.text('Rematch'), findsOneWidget);
    expect(find.text('Ben'), findsOneWidget);
  });

  testWidgets('reactions sheet returns the chosen emoji', (tester) async {
    String? picked;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => picked = await showReactionsSheet(context),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🔥'));
    await tester.pumpAndSettle();
    expect(picked, '🔥');
  });

  test('every corner has a distinct colour and shape', () {
    expect({for (final s in kCornerStyles) s.color}.length, 4);
    expect({for (final s in kCornerStyles) s.shape}.length, 4);
  });
}
