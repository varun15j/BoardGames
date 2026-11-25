/// Board geometry for the 15x15 Race Board grid. Pure Dart.
///
/// Cells are addressed as (row, col). The shared loop has 52 cells running
/// clockwise. Each player ("corner" 0 top-left, 1 top-right, 2 bottom-right,
/// 3 bottom-left) enters the loop at its start cell, walks 51 cells (steps
/// 0..50), turns into a 5-cell home lane (steps 51..55) and finishes in the
/// centre (step 56).
library;

/// A point on the board in cell units. Cell (r, c) has its centre at
/// (r + 0.5, c + 0.5).
class BoardPoint {
  const BoardPoint(this.row, this.col);
  final double row;
  final double col;

  @override
  bool operator ==(Object other) => other is BoardPoint && other.row == row && other.col == col;
  @override
  int get hashCode => Object.hash(row, col);
  @override
  String toString() => 'BoardPoint($row, $col)';
}

class Board {
  Board._();

  static const int size = 15;
  static const int loopLength = 52;
  static const int homeLaneStart = 51;
  static const int homeStep = 56;
  static const int lastLoopStep = 50;

  /// Loop cell index where each corner's tokens enter.
  static const List<int> startIndex = [0, 13, 26, 39];

  /// Safe loop indices: the four start squares and the four stars (8 ahead).
  static const List<int> safeIndices = [0, 8, 13, 21, 26, 34, 39, 47];

  /// The 52 loop cells as (row, col), clockwise from corner 0's start cell.
  static final List<List<int>> loop = _buildLoop();

  static List<List<int>> _buildLoop() {
    final t = <List<int>>[];
    for (var i = 1; i <= 5; i++) {
      t.add([6, i]);
    }
    for (var i = 5; i >= 0; i--) {
      t.add([i, 6]);
    }
    t.add([0, 7]);
    for (var i = 0; i <= 5; i++) {
      t.add([i, 8]);
    }
    for (var i = 9; i <= 14; i++) {
      t.add([6, i]);
    }
    t.add([7, 14]);
    for (var i = 14; i >= 9; i--) {
      t.add([8, i]);
    }
    for (var i = 9; i <= 14; i++) {
      t.add([i, 8]);
    }
    t.add([14, 7]);
    for (var i = 14; i >= 9; i--) {
      t.add([i, 6]);
    }
    for (var i = 5; i >= 0; i--) {
      t.add([8, i]);
    }
    t.add([7, 0]);
    t.add([6, 0]);
    assert(t.length == loopLength);
    return t;
  }

  /// Home lane cells (5 each) for every corner.
  static final List<List<List<int>>> lanes = [
    for (var p = 0; p < 4; p++)
      [
        for (var k = 1; k <= 5; k++)
          switch (p) {
            0 => [7, k],
            1 => [k, 7],
            2 => [7, 14 - k],
            _ => [14 - k, 7],
          },
      ],
  ];

  /// Top-left cell (row, col) of each corner's 6x6 base.
  static const List<List<int>> baseOrigin = [
    [0, 0],
    [0, 9],
    [9, 9],
    [9, 0],
  ];

  /// Token sockets inside a base, relative to [baseOrigin], in (row, col).
  static const List<List<double>> sockets = [
    [2, 2],
    [2, 4],
    [4, 2],
    [4, 4],
  ];

  static const List<List<double>> _centre = [
    [7.5, 6.55],
    [6.55, 7.5],
    [7.5, 8.45],
    [8.45, 7.5],
  ];

  /// Loop index for [step] of [corner], or -1 when the token is not on the
  /// shared loop (in base or in its home lane).
  static int loopIndex(int corner, int step) =>
      step >= 0 && step <= lastLoopStep ? (startIndex[corner] + step) % loopLength : -1;

  static bool isSafeLoopIndex(int index) => index >= 0 && safeIndices.contains(index);

  /// Where a token is drawn, in cell units.
  static BoardPoint pointFor(int corner, int token, int step, int tokenCount) {
    if (step < 0) {
      final o = baseOrigin[corner];
      final s = sockets[token];
      return BoardPoint(o[0] + s[0], o[1] + s[1]);
    }
    if (step <= lastLoopStep) {
      final c = loop[(startIndex[corner] + step) % loopLength];
      return BoardPoint(c[0] + 0.5, c[1] + 0.5);
    }
    if (step < homeStep) {
      final c = lanes[corner][step - homeLaneStart];
      return BoardPoint(c[0] + 0.5, c[1] + 0.5);
    }
    final c = _centre[corner];
    final offset = (token - (tokenCount - 1) / 2) * 0.3;
    // Left/right triangles stack vertically, top/bottom ones horizontally.
    return corner.isEven ? BoardPoint(c[0] + offset, c[1]) : BoardPoint(c[0], c[1] + offset);
  }
}
