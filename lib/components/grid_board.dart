import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../my_game.dart';
import 'tetromino.dart';

class GridBoard extends PositionComponent with HasGameReference<MyGame> {
  static const double cellPadding = 2.0;

  @override
  bool containsPoint(Vector2 point) => true;

  /// Grid state: colour of each filled cell (`null` = empty).
  final List<List<Color?>> gridState = List.generate(
    MyGame.rows,
    (_) => List.filled(MyGame.columns, null),
  );

  // Layout metrics (refreshed on resize).
  double cellSize = 0;
  double mainOffsetX = 0;
  double mainOffsetY = 0;

  /// Cells currently highlighted by the drag preview.
  final Set<(int, int)> _highlightedCells = {};
  Color? _highlightColor;

  /// Drawer slot index currently highlighted (-1 = none).
  int _highlightedDrawerIndex = -1;

  late Tetromino currentPiece;

  /// Track each piece placed on the grid so it can be dragged back.
  final List<({Tetromino piece, int originRow, int originCol})> placedPieces =
      [];

  /// References to drawer holders (refreshed on layout).
  final List<PieceHolder> holders = [];

  /// Pieces currently in the drawer (survives layout rebuilds).
  final List<Tetromino?> drawerPieces =
      List.filled(MyGame.drawerSlots, null);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    currentPiece = Tetromino.random();
    drawerPieces[0] = currentPiece;
    _layoutGrid();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layoutGrid();
  }

  // ────────── piece placement ──────────

  /// Place [piece] on the grid at [originRow], [originCol]. Returns `true` on
  /// success, `false` if the placement is blocked or out of bounds.
  bool placePiece(Tetromino piece, int originRow, int originCol) {
    for (final (r, c) in piece.cells) {
      final row = originRow + r;
      final col = originCol + c;
      if (row < 0 || row >= MyGame.rows || col < 0 || col >= MyGame.columns) {
        return false;
      }
      if (gridState[row][col] != null) return false;
    }
    for (final (r, c) in piece.cells) {
      gridState[originRow + r][originCol + c] = piece.color;
    }
    placedPieces.add(
      (piece: piece, originRow: originRow, originCol: originCol),
    );
    _refreshCellColors();
    return true;
  }

  void _refreshCellColors() {
    for (final child in children) {
      if (child is Cell) {
        final key = (child.row, child.col);
        if (_highlightedCells.contains(key)) {
          child.paint = Paint()
            ..color = (_highlightColor ?? const Color(0xFFFFFFFF)).withAlpha(140);
        } else {
          child.paint = Paint()
            ..color =
                gridState[child.row][child.col] ?? const Color(0xFF2A2A4A);
        }
      }
    }
  }

  /// Update the highlighted preview cells based on current drag position.
  void updateHighlight(Tetromino? piece, Vector2? dragPos,
      {bool isFromGrid = false}) {
    _highlightedCells.clear();
    _highlightColor = null;
    _highlightedDrawerIndex = -1;
    if (piece != null && dragPos != null) {
      final snap = findSnapOrigin(piece, dragPos);
      if (snap != null) {
        _highlightColor = piece.color;
        for (final (r, c) in piece.cells) {
          _highlightedCells.add((snap.$1 + r, snap.$2 + c));
        }
      } else if (isFromGrid) {
        // No valid grid snap – highlight the nearest empty drawer slot.
        final idx = _findNearestEmptySlot(dragPos.x);
        if (idx != -1) _highlightedDrawerIndex = idx;
      }
    }
    _refreshCellColors();
  }

  // ────────── piece retrieval ──────────

  /// Find which placed piece occupies [row],[col], or `null`.
  ({Tetromino piece, int originRow, int originCol})? findPlacedPieceAt(
    int row,
    int col,
  ) {
    for (final pp in placedPieces) {
      for (final (r, c) in pp.piece.cells) {
        if (pp.originRow + r == row && pp.originCol + c == col) return pp;
      }
    }
    return null;
  }

  /// Remove a previously placed piece from the grid.
  void removePlacedPiece(
    ({Tetromino piece, int originRow, int originCol}) pp,
  ) {
    for (final (r, c) in pp.piece.cells) {
      gridState[pp.originRow + r][pp.originCol + c] = null;
    }
    placedPieces.remove(pp);
    _refreshCellColors();
  }

  /// Put [piece] into the empty drawer slot closest to [canvasX].
  /// Falls back to any empty slot. Returns `true` on success.
  bool returnPieceToDrawer(Tetromino piece, [double? canvasX]) {
    final idx = _findNearestEmptySlot(canvasX);
    if (idx == -1) return false;
    drawerPieces[idx] = piece;
    if (idx < holders.length) holders[idx].piece = piece;
    return true;
  }

  /// Find the nearest empty drawer slot to [canvasX], or -1 if none.
  int _findNearestEmptySlot([double? canvasX]) {
    if (holders.isEmpty) return -1;
    int best = -1;
    double bestDist = double.infinity;
    for (int i = 0; i < MyGame.drawerSlots; i++) {
      if (drawerPieces[i] != null) continue;
      if (canvasX == null) return i; // no position hint, take first
      final slotCenterX =
          holders[i].position.x + holders[i].size.x / 2;
      final dist = (canvasX - slotCenterX).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    return best;
  }

  // ────────── snap logic ──────────

  /// Given the canvas-space position of the dragged piece's top-left corner,
  /// return the best grid origin `(row, col)` or `null` if invalid.
  (int, int)? findSnapOrigin(Tetromino piece, Vector2 dragPos) {
    int minR = 999, maxR = 0, minC = 999, maxC = 0;
    for (final (r, c) in piece.cells) {
      if (r < minR) minR = r;
      if (r > maxR) maxR = r;
      if (c < minC) minC = c;
      if (c > maxC) maxC = c;
    }

    final step = cellSize + cellPadding;

    // Centre of the dragged bounding box in canvas space.
    final centerX = dragPos.x + (maxC - minC + 1) * step / 2;
    final centerY = dragPos.y + (maxR - minR + 1) * step / 2;

    // Nearest grid cell under that centre.
    final centerGridCol = ((centerX - mainOffsetX + step / 2) / step).floor();
    final centerGridRow = ((centerY - mainOffsetY + step / 2) / step).floor();

    // Map shape-centre cell → that grid cell → derive piece origin.
    final midR = (minR + maxR) ~/ 2;
    final midC = (minC + maxC) ~/ 2;
    final originRow = centerGridRow - midR;
    final originCol = centerGridCol - midC;

    // Validate every cell.
    for (final (r, c) in piece.cells) {
      final row = originRow + r;
      final col = originCol + c;
      if (row < 0 || row >= MyGame.rows || col < 0 || col >= MyGame.columns) {
        return null;
      }
      if (gridState[row][col] != null) return null;
    }
    return (originRow, originCol);
  }

  // ────────── layout ──────────

  void _layoutGrid() {
    final screenSize = game.size;

    final gap = 16.0;
    final totalVerticalCells = MyGame.rows + 1;
    final availableHeight = screenSize.y - gap;
    final maxCellByHeight =
        (availableHeight - cellPadding * (totalVerticalCells + 2)) /
        totalVerticalCells;
    final maxCellByWidth =
        (screenSize.x - cellPadding * (MyGame.columns + 1)) / MyGame.columns;
    cellSize = maxCellByHeight < maxCellByWidth
        ? maxCellByHeight
        : maxCellByWidth;

    final mainGridWidth =
        MyGame.columns * (cellSize + cellPadding) + cellPadding;
    final mainGridHeight = MyGame.rows * (cellSize + cellPadding) + cellPadding;

    final holderSize = cellSize;
    final drawerWidth =
        MyGame.drawerSlots * (holderSize + cellPadding) + cellPadding;
    final totalHeight = mainGridHeight + gap + holderSize;
    final topY = (screenSize.y - totalHeight) / 2;

    mainOffsetX = (screenSize.x - mainGridWidth) / 2 + cellPadding;
    mainOffsetY = topY + cellPadding;

    removeAll(children);
    holders.clear();

    // Main grid
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
            color: gridState[row][col],
            board: this,
          ),
        );
      }
    }

    // Drawer row
    final drawerOffsetX = (screenSize.x - drawerWidth) / 2 + cellPadding;
    final drawerOffsetY = topY + mainGridHeight + gap;

    for (int i = 0; i < MyGame.drawerSlots; i++) {
      final x = drawerOffsetX + i * (holderSize + cellPadding);
      final holder = PieceHolder(
        position: Vector2(x, drawerOffsetY),
        size: Vector2.all(holderSize),
        piece: drawerPieces[i],
        board: this,
        index: i,
      );
      holders.add(holder);
      add(holder);
    }
  }
}

// ─────────────────────── Cell ───────────────────────

class Cell extends RectangleComponent with DragCallbacks {
  final int row;
  final int col;
  final GridBoard? board;

  Cell({
    required super.position,
    required super.size,
    required this.row,
    required this.col,
    Color? color,
    this.board,
  }) : super(paint: Paint()..color = color ?? const Color(0xFF2A2A4A));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }

  // ── drag-back handling ──

  DraggablePiece? _dragPiece;
  ({Tetromino piece, int originRow, int originCol})? _draggedPlacement;

  @override
  void onDragStart(DragStartEvent event) {
    if (board == null) return;
    final pp = board!.findPlacedPieceAt(row, col);
    if (pp == null) return;
    super.onDragStart(event);

    _draggedPlacement = pp;
    board!.removePlacedPiece(pp);

    final step = board!.cellSize + GridBoard.cellPadding;
    int minR = 999, maxR = 0, minC = 999, maxC = 0;
    for (final (r, c) in pp.piece.cells) {
      if (r < minR) minR = r;
      if (r > maxR) maxR = r;
      if (c < minC) minC = c;
      if (c > maxC) maxC = c;
    }
    final pieceW = (maxC - minC + 1) * step;
    final pieceH = (maxR - minR + 1) * step;

    final pos = event.canvasPosition;
    _dragPiece = DraggablePiece(
      piece: pp.piece,
      cellSize: board!.cellSize,
      cellPadding: GridBoard.cellPadding,
      position: Vector2(pos.x - pieceW / 2, pos.y - pieceH / 2),
    );
    board!.game.add(_dragPiece!);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    _dragPiece?.position.add(event.canvasDelta);
    if (_dragPiece != null && _draggedPlacement != null) {
      board!.updateHighlight(_draggedPlacement!.piece, _dragPiece!.position,
          isFromGrid: true);
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _finishDrag();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _finishDrag(forceRestore: true);
  }

  void _finishDrag({bool forceRestore = false}) {
    if (_dragPiece == null || _draggedPlacement == null) return;

    final piece = _draggedPlacement!.piece;
    bool placed = false;

    if (!forceRestore) {
      final snap = board!.findSnapOrigin(piece, _dragPiece!.position);
      if (snap != null) {
        board!.placePiece(piece, snap.$1, snap.$2);
        placed = true;
      } else {
        placed = board!.returnPieceToDrawer(piece, _dragPiece!.position.x);
      }
    }

    if (!placed) {
      board!.placePiece(
        piece,
        _draggedPlacement!.originRow,
        _draggedPlacement!.originCol,
      );
    }

    board!.updateHighlight(null, null);
    _dragPiece!.removeFromParent();
    _dragPiece = null;
    _draggedPlacement = null;
  }
}

// ────────────────────── PieceHolder ──────────────────────

/// Drawer square that shows a miniature tetromino and is draggable.
class PieceHolder extends PositionComponent with DragCallbacks {
  Tetromino? piece;
  final GridBoard board;
  final int index;
  DraggablePiece? _dragPiece;

  PieceHolder({
    required super.position,
    required super.size,
    this.piece,
    required this.board,
    required this.index,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }

  // ── drag handling ──

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (piece == null) return;

    final step = board.cellSize + GridBoard.cellPadding;
    int minR = 999, maxR = 0, minC = 999, maxC = 0;
    for (final (r, c) in piece!.cells) {
      if (r < minR) minR = r;
      if (r > maxR) maxR = r;
      if (c < minC) minC = c;
      if (c > maxC) maxC = c;
    }
    final pieceW = (maxC - minC + 1) * step;
    final pieceH = (maxR - minR + 1) * step;

    // Centre the full-size piece on the touch point.
    final pos = event.canvasPosition;
    _dragPiece = DraggablePiece(
      piece: piece!,
      cellSize: board.cellSize,
      cellPadding: GridBoard.cellPadding,
      position: Vector2(pos.x - pieceW / 2, pos.y - pieceH / 2),
    );
    board.game.add(_dragPiece!);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    _dragPiece?.position.add(event.canvasDelta);
    if (_dragPiece != null && piece != null) {
      board.updateHighlight(piece, _dragPiece!.position);
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (_dragPiece == null) return;

    final snap = board.findSnapOrigin(piece!, _dragPiece!.position);
    if (snap != null) {
      board.placePiece(piece!, snap.$1, snap.$2);
      piece = null;
      board.drawerPieces[index] = null;
    }

    board.updateHighlight(null, null);
    _dragPiece!.removeFromParent();
    _dragPiece = null;
  }

  // ── rendering ──

  @override
  void render(Canvas canvas) {
    final isHighlighted = board._highlightedDrawerIndex == index;
    canvas.drawRect(
      size.toRect(),
      Paint()
        ..color = isHighlighted
            ? const Color(0xFF4A4A6A)
            : const Color(0xFF2A2A4A),
    );
    if (isHighlighted) {
      canvas.drawRect(
        size.toRect(),
        Paint()
          ..color = const Color(0xFF8888FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
    if (piece == null) return;

    int minRow = 999, maxRow = 0, minCol = 999, maxCol = 0;
    for (final (r, c) in piece!.cells) {
      if (r < minRow) minRow = r;
      if (r > maxRow) maxRow = r;
      if (c < minCol) minCol = c;
      if (c > maxCol) maxCol = c;
    }
    final pieceRows = maxRow - minRow + 1;
    final pieceCols = maxCol - minCol + 1;

    final padding = size.x * 0.15;
    final available = size.x - padding * 2;
    final miniCellSize =
        available / (pieceRows > pieceCols ? pieceRows : pieceCols);
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
          Rect.fromLTWH(
            x,
            y,
            miniCellSize - miniGap * 2,
            miniCellSize - miniGap * 2,
          ),
          const Radius.circular(2),
        ),
        fillPaint,
      );
    }
  }
}

// ──────────────── DraggablePiece (visual ghost while dragging) ────────────────

/// Full grid-scale rendering of a tetromino that follows the pointer during a
/// drag. Each cell of the tetromino is drawn at the same size as a grid cell.
class DraggablePiece extends PositionComponent {
  final Tetromino piece;
  final double cellSize;
  final double cellPadding;

  DraggablePiece({
    required this.piece,
    required this.cellSize,
    required this.cellPadding,
    required super.position,
  }) : super(priority: 100);

  @override
  void render(Canvas canvas) {
    int minR = 999, minC = 999;
    for (final (r, c) in piece.cells) {
      if (r < minR) minR = r;
      if (c < minC) minC = c;
    }

    final step = cellSize + cellPadding;
    final gap = 1.0;
    final fillPaint = Paint()..color = piece.color;

    for (final (r, c) in piece.cells) {
      final x = (c - minC) * step + gap;
      final y = (r - minR) * step + gap;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, cellSize - gap * 2, cellSize - gap * 2),
          const Radius.circular(3),
        ),
        fillPaint,
      );
    }
  }
}
