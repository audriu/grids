import 'dart:math';
import 'dart:ui';

/// All 7 standard Tetris tetromino shapes, defined in a 2-row x 4-column grid.
/// true = filled cell, false = empty.
enum TetrominoType {
  /// ####
  I,

  /// ##
  /// ##
  O,

  ///  #
  /// ###
  T,

  /// #
  /// ###
  L,

  ///   #
  /// ###
  J,

  /// ##
  ///  ##
  Z,

  ///  ##
  /// ##
  S,
}

class Tetromino {
  final TetrominoType type;

  /// Level displayed at the centre of the piece (default 1).
  int level;

  /// Shape as list of (row, col) offsets (mutable for rotation).
  late List<(int, int)> cells;

  /// Color for this piece.
  late final Color color;

  Tetromino(this.type, {this.level = 1}) {
    cells = _shapeCells(type);
    color = _shapeColor(type);
  }

  /// Rotate 90° clockwise: (r, c) → (c, -r), then normalise to top-left.
  void rotateCW() {
    cells = _normalise(cells.map((rc) => (rc.$2, -rc.$1)).toList());
  }

  /// Rotate 90° counter-clockwise: (r, c) → (-c, r), then normalise.
  void rotateCCW() {
    cells = _normalise(cells.map((rc) => (-rc.$2, rc.$1)).toList());
  }

  static List<(int, int)> _normalise(List<(int, int)> raw) {
    int minR = raw.first.$1, minC = raw.first.$2;
    for (final (r, c) in raw) {
      if (r < minR) minR = r;
      if (c < minC) minC = c;
    }
    return raw.map((rc) => (rc.$1 - minR, rc.$2 - minC)).toList();
  }

  static Tetromino random({int level = 1}) {
    final types = TetrominoType.values;
    return Tetromino(types[Random().nextInt(types.length)], level: level);
  }

  static List<(int, int)> _shapeCells(TetrominoType type) {
    switch (type) {
      case TetrominoType.I:
        return [(1, 0), (1, 1), (1, 2), (1, 3)];
      case TetrominoType.O:
        return [(0, 1), (0, 2), (1, 1), (1, 2)];
      case TetrominoType.T:
        return [(0, 1), (1, 0), (1, 1), (1, 2)];
      case TetrominoType.L:
        return [(0, 0), (1, 0), (1, 1), (1, 2)];
      case TetrominoType.J:
        return [(0, 2), (1, 0), (1, 1), (1, 2)];
      case TetrominoType.Z:
        return [(0, 0), (0, 1), (1, 1), (1, 2)];
      case TetrominoType.S:
        return [(0, 1), (0, 2), (1, 0), (1, 1)];
    }
  }

  static Color _shapeColor(TetrominoType type) {
    switch (type) {
      case TetrominoType.I:
        return const Color(0xFF00E5FF);
      case TetrominoType.O:
        return const Color(0xFFFFD600);
      case TetrominoType.T:
        return const Color(0xFFAA00FF);
      case TetrominoType.L:
        return const Color(0xFFFF6D00);
      case TetrominoType.J:
        return const Color(0xFF2979FF);
      case TetrominoType.Z:
        return const Color(0xFFFF1744);
      case TetrominoType.S:
        return const Color(0xFF00E676);
    }
  }
}
