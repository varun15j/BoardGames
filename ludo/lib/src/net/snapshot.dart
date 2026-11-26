/// Turning a running match into JSON and back. Pure Dart.
library;

import '../game/models.dart';

/// Everything another phone needs to draw the current moment.
class Snapshot {
  const Snapshot({
    required this.steps,
    required this.display,
    required this.turn,
    required this.finishOrder,
    required this.captures,
    required this.sixes,
    required this.lastRoll,
    required this.phase,
    required this.die,
    required this.rollId,
    required this.movable,
    required this.flying,
    required this.status,
    required this.notes,
    required this.timerMs,
    required this.timerTotalMs,
    required this.takenOver,
  });

  final List<List<int>> steps;
  final List<List<int>> display;
  final int turn;
  final List<int> finishOrder;
  final List<int> captures;
  final List<int> sixes;
  final int? lastRoll;
  final String phase;
  final int die;
  final int rollId;
  final List<int> movable;
  final List<TokenRef> flying;
  final String status;
  final List<String> notes;
  final int timerMs;
  final int timerTotalMs;
  final List<int> takenOver;

  Map<String, Object?> toJson() => {
        'steps': steps,
        'display': display,
        'turn': turn,
        'finish': finishOrder,
        'captures': captures,
        'sixes': sixes,
        'lastRoll': lastRoll,
        'phase': phase,
        'die': die,
        'rollId': rollId,
        'movable': movable,
        'flying': [
          for (final t in flying) [t.seat, t.token],
        ],
        'status': status,
        'notes': notes,
        'timer': timerMs,
        'timerTotal': timerTotalMs,
        'takenOver': takenOver,
      };

  /// Throws a [FormatException] if the data has the wrong shape.
  factory Snapshot.fromJson(Map<String, Object?> j) {
    try {
      List<int> ints(Object? o) => [for (final v in o! as List) v as int];
      List<List<int>> rows(Object? o) => [for (final r in o! as List) ints(r)];
      return Snapshot(
        steps: rows(j['steps']),
        display: rows(j['display']),
        turn: j['turn']! as int,
        finishOrder: ints(j['finish']),
        captures: ints(j['captures']),
        sixes: ints(j['sixes']),
        lastRoll: j['lastRoll'] as int?,
        phase: j['phase']! as String,
        die: j['die']! as int,
        rollId: j['rollId']! as int,
        movable: ints(j['movable']),
        flying: [for (final r in j['flying']! as List) TokenRef((r as List)[0] as int, r[1] as int)],
        status: j['status']! as String,
        notes: [for (final n in j['notes']! as List) n as String],
        timerMs: j['timer']! as int,
        timerTotalMs: j['timerTotal']! as int,
        takenOver: ints(j['takenOver']),
      );
    } on TypeError {
      throw const FormatException('bad snapshot');
    }
  }
}
