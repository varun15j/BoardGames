# Board Games

A Flutter monorepo of offline board games, Android first. The first game is **Race Board**, an original Ludo-style race for 2-4 players (vs bots, pass and play, quick match).

## Layout

| Folder | What it is |
| --- | --- |
| `app/` | The "Board Games" host app. Game picker home screen; depends on every game by path. |
| `game_kit/` | Shared package for things every game reuses: theme and fonts, night background, gold buttons, dice, player pods, turn-timer ring, reactions sheet and floating emoji, confetti, a generic result screen, token discs. |
| `ludo/` | The Race Board module (a Flutter package). `lib/src/game` is pure Dart (board geometry, rules, bot, no Flutter imports); `lib/src/ui` holds the screens, board painter and game controller. Public API is `lib/ludo.dart`. |
| `ludo/example/` | A tiny Android app that runs the Ludo module on its own. |

```
app ──► ludo ──► game_kit
 └──────────────► game_kit
```

## Running

```powershell
cd app
flutter run            # the full picker app
cd ../ludo/example
flutter run            # Race Board alone
```

Tests and analysis (run in each of `game_kit`, `ludo`, `ludo/example`, `app`):

```powershell
flutter analyze
flutter test
```

Debug APK: `cd app; flutter build apk --debug`.

## Race Board rules

- 15x15 board, 52-cell clockwise loop, a 5-cell home lane, finish in the centre (step 56). 4 tokens each (Quick: 2, one starts out).
- A token leaves base only on a 6; finishing needs the exact roll.
- Landing on a rival on a non-safe square sends it home. Safe squares are the four start squares and the four stars (8 ahead of each start).
- Bonus roll on a 6, a capture, or reaching home. Three 6s in a row end the turn.
- 15 second turn timer, then the game rolls / plays the best move. A lone legal move is played automatically.
- Bot priority: capture > finish > leave base > safe square > enter home lane > furthest token. The easy bot plays a random legal move half the time.
- The match ends when all but one player have finished; results show ranks, captures and sixes.

Unfinished games are saved with `shared_preferences` (Save & exit, and after every turn) and offered as "Resume game" on the Ludo home screen.

## Using the Ludo module from another app

```yaml
dependencies:
  ludo:
    path: ../ludo           # or a git dependency with `path: ludo`
```

```dart
Navigator.of(context).push(LudoGame.route());
// or put LudoGame() anywhere a widget fits, e.g. MaterialApp(home: LudoGame())
```

Wrap the app in `KitTheme.data()` (from `game_kit`) so fonts and colours match; `LudoGame` also applies it itself.

## Adding a new game

1. `flutter create --template=package <name>` at the repo root. Add `game_kit` as a path dependency (`path: ../game_kit`).
2. Keep rules in pure Dart under `lib/src/game` and write unit tests for them first. Put screens under `lib/src/ui` and reuse `game_kit` widgets (`DieView`, `PlayerPod`, `ResultView`, `showReactionsSheet`, `ConfettiOverlay`, `GoldButton`, `NightBackground`).
3. Export a small public API from `lib/<name>.dart`, such as a `<Name>Game` widget and a static `route()`.
4. Optionally add `<name>/example/` (`flutter create --platforms android example`) that runs the module alone.
5. In `app/pubspec.yaml` add the path dependency, then add a `GameEntry` to `kGames` in `app/lib/games.dart`. The picker shows it automatically.
6. Anything that turns out to be useful in two games belongs in `game_kit`.

## Notes

- Fonts (Baloo 2, Nunito) are fetched by `google_fonts` the first time the app runs online and cached; offline on the very first launch the system font is used. Android release builds need the `INTERNET` permission for that, which is declared.
- Sound uses the system click, and haptics use the platform haptic feedback; both can be switched off from the pause menu. "Reduce motion" (system setting) shortens animations and removes the shake and confetti.
- Not in the MVP: online play, accounts, custom sound effects, tablet layouts.
