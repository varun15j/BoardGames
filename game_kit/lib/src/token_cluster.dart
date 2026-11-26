import 'dart:ui' show Offset;

/// How many tokens on one square before a count badge is shown.
const int kCountBadgeFrom = 3;

bool showCountBadge(int tokens) => tokens >= kCountBadgeFrom;

/// Where [count] tokens sharing a square sit, in cells from its centre: a
/// pair side by side, three or four in a two-by-two, more in rows of three.
List<Offset> clusterOffsets(int count) {
  if (count <= 1) return const [Offset.zero];
  if (count == 2) return const [Offset(-0.23, 0), Offset(0.23, 0)];
  if (count <= 4) {
    return const [Offset(-0.23, -0.19), Offset(0.23, -0.19), Offset(-0.23, 0.23), Offset(0.23, 0.23)]
        .sublist(0, count);
  }
  final rows = (count / 3).ceil();
  return [
    for (var i = 0; i < count; i++)
      Offset((i % 3 - 1) * 0.28, rows == 1 ? 0 : -0.24 + (i ~/ 3) * (0.48 / (rows - 1))),
  ];
}

/// Token scale when [count] share a square.
double clusterScale(int count) => count <= 1 ? 1 : (count <= 4 ? 0.74 : 0.58);
