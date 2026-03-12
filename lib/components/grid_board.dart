import 'dart:ui';

import 'package:flame/components.dart';

import '../my_game.dart';
import 'tetromino.dart';

class GridBoard extends PositionComponent with HasGameReference<MyGame> {
  static const double cellPadding = 2.0;

  late Tetromino currentPiece;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    currentPiece = Tetromino.random();
    _layoutGrid();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layoutGrid();
  }

  void _layoutGrid() {
    final screenSize = game.size;

    // Calculate cell size so main grid + holder square fit vertically
    final gap = 16.0;
    // holder is 1 cell tall
    final totalVerticalCells = MyGame.rows + 1;
    final availableHeight = screenSize.y - gap;
    final maxCellByHeight =
        (availableHeight - cellPadding * (totalVerticalCells + 2)) /
            totalVerticalCells;
    final maxCellByWidth =
        (screenSize.x - cellPadding * (MyGame.columns + 1)) / MyGame.columns;
    final cellSize = maxCellByHeight < maxCellByWidth
        ? maxCellByHeight
        : maxCellByWidth;

    // Main grid dimensions
    final mainGridWidth =
        MyGame.columns * (cellSize + cellPadding) + cellPadding;
    final mainGridHeight = MyGame.rows * (cellSize + cellPadding) + cellPadding;

    final holderSize = cellSize;
    final drawerWidth =
        MyGame.drawerSlots * (holderSize + cellPadding) + cellPadding;
    final totalHeight = mainGridHeight + gap + holderSize;
    final topY = (screenSize.y - totalHeight) / 2;

    // Main grid offset (centered horizontally)
    final mainOffsetX = (screenSize.x - mainGridWidth) / 2 + cellPadding;
    final mainOffsetY = topY + cellPadding;

    removeAll(children);

    // Main 7x7 grid
    for (int row = 0; row < MyGame.rows; row++) {
      for (int col = 0; col < MyGame.columns; col++) {
        final x = mainOffsetX + col * (cellSize + cellPadding);
        final y = mainOffsetY + row * (cellSize + cellPadding);
        add(
          Cell(
            position: Vector2(x, y),
            size: Vector2.all(cellSize),
            row: row,
            col: col,
          ),
        );
      }
    }

    // Drawer: 8 holder cells in a row, centered below the main grid
    final drawerOffsetX = (screenSize.x - drawerWidth) / 2 + cellPadding;
    final drawerOffsetY = topY + mainGridHeight + gap;

    for (int i = 0; i < MyGame.drawerSlots; i++) {
      final x = drawerOffsetX + i * (holderSize + cellPadding);
      add(
        PieceHolder(
          position: Vector2(x, drawerOffsetY),
          size: Vector2.all(holderSize),
          piece: i == 0 ? currentPiece : null,
        ),
      );
    }
  }
}

class Cell extends RectangleComponent {
  final int row;
  final int col;

  Cell({
    required super.position,
    required super.size,
    required this.row,
    required this.col,
  }) : super(paint: Paint()..color = const Color(0xFF2A2A4A));
}

/// A single square that renders a miniature tetromino inside it.
class PieceHolder extends PositionComponent {
  final Tetromino? piece;

  PieceHolder({
    required super.position,
    required super.size,
    this.piece,
  });

  @override
  void render(Canvas canvas) {
    // Background
    canvas.drawRect(
      size.toRect(),
      Paint()..color = const Color(0xFF2A2A4A),
    );

    if (piece == null) return;

    // Determine bounding box of the piece cells
    int minRow = 999, maxRow = 0, minCol = 999, maxCol = 0;
    for (final (r, c) in piece!.cells) {
      if (r < minRow) minRow = r;
      if (r > maxRow) maxRow = r;
      if (c < minCol) minCol = c;
      if (c > maxCol) maxCol = c;
    }
    final pieceRows = maxRow - minRow + 1;
    final pieceCols = maxCol - minCol + 1;

    // Fit the piece into the square with some padding
    final padding = size.x * 0.15;
    final available = size.x - padding * 2;
    final miniCellSize = available / (pieceRows > pieceCols ? pieceRows : pieceCols);
    final miniGap = 1.0;

    final totalW = pieceCols * miniCellSize;
    final totalH = pieceRows * miniCellSize;
    final startX = padding + (available - totalW) / 2;
    final startY = padding + (available - totalH) / 2;

    final fillPaint = Paint()..color = piece!.color;

    for (final (r, c) in piece!.cells) {
      final x = startX + (c - minCol) * miniCellSize + miniGap;
      final y = startY + (r - minRow) * miniCellSize + miniGap;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, miniCellSize - miniGap * 2, miniCellSize - miniGap * 2),
          const Radius.circular(2),
        ),
        fillPaint,
      );
    }
  }
}
