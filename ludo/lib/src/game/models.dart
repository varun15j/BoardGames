import 'board.dart';

enum BotLevel { easy, normal }

/// One seat at the table. Seats play in list order (clockwise).
class SeatConfig {
  const SeatConfig({
    required this.name,
    required this.corner,
    this.isBot = false,
    this.level = BotLevel.normal,
    this.avatar,
  });

  /// The seat's avatar or photo, as encoded by the UI; null for the default.
  final String? avatar;

  final String name;

  /// Board corner (0 top-left, 1 top-right, 2 bottom-right, 3 bottom-left).
  final int corner;
  final bool isBot;
  final BotLevel level;

  SeatConfig copyWith({String? name, bool? isBot, BotLevel? level, String? avatar}) => SeatConfig(
        name: name ?? this.name,
        corner: corner,
        isBot: isBot ?? this.isBot,
        level: level ?? this.level,
        avatar: avatar ?? this.avatar,
      );

  Map<String, Object?> toJson() =>
      {'name': name, 'corner': corner, 'bot': isBot, 'level': level.name, 'avatar': avatar};

  factory SeatConfig.fromJson(Map<String, Object?> j) => SeatConfig(
        name: j['name']! as String,
        corner: j['corner']! as int,
        isBot: j['bot']! as bool,
        level: BotLevel.values.byName(j['level']! as String),
        avatar: j['avatar'] as String?,
      );
}

/// Everything chosen on the match setup screen.
class MatchConfig {
  const MatchConfig({required this.seats, this.quick = false, this.passAndPlay = false});

  final List<SeatConfig> seats;

  /// Quick match: two tokens each, one of them already out.
  final bool quick;
  final bool passAndPlay;

  int get tokensPerPlayer => quick ? 2 : 4;
  int get humanCount => seats.where((s) => !s.isBot).length;

  /// Corners used for [count] players: opposite corners for two, and so on,
  /// in clockwise turn order starting bottom-left.
  static List<int> cornersFor(int count) => switch (count) {
        2 => const [3, 1],
        3 => const [3, 0, 1],
        _ => const [3, 0, 1, 2],
      };

  Map<String, Object?> toJson() =>
      {'seats': [for (final s in seats) s.toJson()], 'quick': quick, 'pass': passAndPlay};

  factory MatchConfig.fromJson(Map<String, Object?> j) => MatchConfig(
        seats: [for (final s in j['seats']! as List) SeatConfig.fromJson((s as Map).cast<String, Object?>())],
        quick: j['quick']! as bool,
        passAndPlay: (j['pass'] as bool?) ?? false,
      );
}

class TokenRef {
  const TokenRef(this.seat, this.token);
  final int seat;
  final int token;

  @override
  bool operator ==(Object other) => other is TokenRef && other.seat == seat && other.token == token;
  @override
  int get hashCode => Object.hash(seat, token);
  @override
  String toString() => 'TokenRef($seat, $token)';
}

/// Mutable game state. Token steps: -1 in base, 0..50 on the loop, 51..55 in
/// the home lane, 56 home.
class GameState {
  GameState({
    required this.config,
    required this.steps,
    this.turn = 0,
    this.sixStreak = 0,
    List<int>? finishOrder,
    List<int>? captures,
    List<int>? sixesRolled,
    this.lastRoll,
  })  : finishOrder = finishOrder ?? [],
        captures = captures ?? List.filled(config.seats.length, 0),
        sixesRolled = sixesRolled ?? List.filled(config.seats.length, 0);

  factory GameState.fresh(MatchConfig config) {
    final n = config.tokensPerPlayer;
    return GameState(
      config: config,
      steps: [
        for (final _ in config.seats) [for (var i = 0; i < n; i++) config.quick && i == 0 ? 0 : -1],
      ],
    );
  }

  final MatchConfig config;

  /// steps[seat][token].
  final List<List<int>> steps;
  int turn;
  int sixStreak;
  final List<int> finishOrder;
  final List<int> captures;
  final List<int> sixesRolled;
  int? lastRoll;

  int get seatCount => config.seats.length;
  int cornerOf(int seat) => config.seats[seat].corner;
  int get tokenCount => config.tokensPerPlayer;
  bool hasFinished(int seat) => steps[seat].every((s) => s == Board.homeStep);
  int homeCount(int seat) => steps[seat].where((s) => s == Board.homeStep).length;

  GameState clone() => GameState(
        config: config,
        steps: [for (final r in steps) List<int>.of(r)],
        turn: turn,
        sixStreak: sixStreak,
        finishOrder: List<int>.of(finishOrder),
        captures: List<int>.of(captures),
        sixesRolled: List<int>.of(sixesRolled),
        lastRoll: lastRoll,
      );

  Map<String, Object?> toJson() => {
        'config': config.toJson(),
        'steps': steps,
        'turn': turn,
        'sixStreak': sixStreak,
        'finishOrder': finishOrder,
        'captures': captures,
        'sixesRolled': sixesRolled,
        'lastRoll': lastRoll,
      };

  factory GameState.fromJson(Map<String, Object?> j) {
    List<int> ints(Object? o) => [for (final v in o! as List) v as int];
    final config = MatchConfig.fromJson((j['config']! as Map).cast<String, Object?>());
    return GameState(
      config: config,
      steps: [for (final r in j['steps']! as List) ints(r)],
      turn: j['turn']! as int,
      sixStreak: j['sixStreak']! as int,
      finishOrder: ints(j['finishOrder']),
      captures: ints(j['captures']),
      sixesRolled: ints(j['sixesRolled']),
      lastRoll: j['lastRoll'] as int?,
    );
  }
}
