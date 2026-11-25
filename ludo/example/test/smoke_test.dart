import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:ludo_example/main.dart';

void main() {
  testWidgets('example app opens the Race Board home', (tester) async {
    KitTheme.useGoogleFonts = false;
    await tester.pumpWidget(const LudoExampleApp());
    expect(find.text('Race Board'), findsOneWidget);
    expect(find.text('Quick Match'), findsOneWidget);
  });
}
