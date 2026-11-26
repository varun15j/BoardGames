/// Race Board - an original Ludo-style game module.
///
/// Embed it with [LudoGame]:
///
/// ```dart
/// Navigator.of(context).push(LudoGame.route());
/// ```
library;

export 'src/game/board.dart';
export 'src/game/bot.dart';
export 'src/game/models.dart';
export 'src/game/rules.dart';
export 'src/net/channel.dart';
export 'src/net/client_room.dart';
export 'src/net/discovery.dart';
export 'src/net/host_room.dart';
export 'src/net/protocol.dart';
export 'src/net/snapshot.dart';
export 'src/ui/ludo_game.dart';
