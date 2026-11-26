import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:ludo/ludo.dart';
import 'package:ludo/src/ui/wifi_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoRooms extends RoomDiscovery {
  const _NoRooms();
  @override
  Future<RoomAddress?> find(String code, {Duration timeout = const Duration(seconds: 8)}) async => null;
}

void main() {
  setUp(() {
    KitTheme.useGoogleFonts = false;
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> phone(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pump();
  }

  testWidgets('Home offers Wi-Fi play with host and join', (tester) async {
    await phone(tester, const LudoGame());
    await tester.ensureVisible(find.text('Play on Wi-Fi'));
    await tester.tap(find.text('Play on Wi-Fi'));
    await tester.pumpAndSettle();
    expect(find.text('Host a room'), findsOneWidget);
    expect(find.text('Join a room'), findsOneWidget);
    expect(find.textContaining('same Wi-Fi'), findsOneWidget);
  });

  testWidgets('joining explains bad input and a room that is not found', (tester) async {
    await phone(tester, const JoinScreen(discovery: _NoRooms()));
    await tester.tap(find.text('Join'));
    await tester.pump();
    expect(find.text('Enter the 4-character room code.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('join-code')), 'abcd');
    await tester.tap(find.text('Join'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('No room found'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('join-address')), 'nonsense');
    await tester.tap(find.text('Join'));
    await tester.pump();
    expect(find.text('That address doesn\'t look right.'), findsOneWidget);
  });
}
