import 'dart:ui';

import 'package:flame/components.dart';

import '../my_game.dart';

class GridBoard extends PositionComponent with HasGameReference<MyGame> {
  static const double cellPadding = 2.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _layoutGrid();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layoutGrid();
  }

  void _layoutGrid() {
    final screenSize = game.size;

    // Calculate cell size so both grids fit vertically with a gap
    final gap = 16.0;
    final totalRows = MyGame.rows + MyGame.drawerRows;
    final availableHeight = screenSize.y - gap;
    final maxCellByHeight = (availableHeight - cellPadding * (totalRows + 2)) / totalRows;
    final maxCellByWidth = (screenSize.x - cellPadding * (MyGame.columns + 1)) / MyGame.columns;
    final cellSize = maxCellByHeight < maxCellByWidth ? maxCellByHeight : maxCellByWidth;

    // Main grid dimensions
    final mainGridWidth = MyGame.columns * (cellSize + cellPadding) + cellPadding;
    final mainGridHeight = MyGame.rows * (cellSize + cellPadding) + cellPadding;

    // Drawer grid dimensions
    final drawerWidth = MyGame.drawerColumns * (cellSize + cellPadding) + cellPadding;
    final drawerHeight = MyGame.drawerRows * (cellSize + cellPadding) + cellPadding;

    final totalHeight = mainGridHeight + gap + drawerHeight;
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
        add(Cell(
          position: Vector2(x, y),
          size: Vector2.all(cellSize),
          row: row,
          col: col,
        ));
      }
    }

    // Drawer grid (2x4, centered horizontally below main grid)
    final drawerOffsetX = (screenSize.x - drawerWidth) / 2 + cellPadding;
    final drawerOffsetY = topY + mainGridHeight + gap + cellPadding;

    for (int row = 0; row < MyGame.drawerRows; row++) {
      for (int col = 0; col < MyGame.drawerColumns; col++) {
        final x = drawerOffsetX + col * (cellSize + cellPadding);
        final y = drawerOffsetY + row * (cellSize + cellPadding);
        add(DrawerCell(
          position: Vector2(x, y),
          size: Vector2.all(cellSize),
          row: row,
          col: col,
        ));
      }
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
  }) : super(
          paint: Paint()..color = const Color(0xFF2A2A4A),
        );
}

class DrawerCell extends RectangleComponent {
  final int row;
  final int col;

  DrawerCell({
    required super.position,
    required super.size,
    required this.row,
    required this.col,
  }) : super(
          paint: Paint()..color = const Color(0xFF3A3A5A),
        );
}
