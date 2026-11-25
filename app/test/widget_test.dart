import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';

import 'package:board_games/main.dart';

void main() {
  setUp(() => KitTheme.useGoogleFonts = false);

  testWidgets('picker shows Race Board first and opens it', (tester) async {
    await tester.pumpWidget(const BoardGamesApp());
    expect(find.text('Board Games'), findsOneWidget);
    expect(find.text('Race Board'), findsOneWidget);
    await tester.tap(find.text('Race Board'));
    await tester.pumpAndSettle();
    expect(find.text('vs Bots'), findsOneWidget);
    expect(find.text('Quick Match'), findsOneWidget);
  });
}
