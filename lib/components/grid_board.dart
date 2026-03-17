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

  /// Drawer slot index highlighted for a merge (red), -1 = none.
  int _mergeHighlightIndex = -1;

  /// Grid cells highlighted for a merge on the grid.
  final Set<(int, int)> _gridMergeHighlightCells = {};

  /// Whether the trash cell is currently highlighted.
  bool _trashHighlighted = false;

  /// Reference to the trash holder (refreshed on layout).
  TrashHolder? _trashHolder;

  /// Scrollable drawer container.
  DrawerContainer? _drawerContainer;

  late Tetromino currentPiece;

  /// Track each piece placed on the grid so it can be dragged back.
  final List<({Tetromino piece, int originRow, int originCol})> placedPieces =
      [];

  /// References to drawer holders (refreshed on layout).
  final List<PieceHolder> holders = [];

  /// Pieces currently in the drawer (survives layout rebuilds).
  final List<Tetromino?> drawerPieces = List.filled(MyGame.drawerSlots, null);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    currentPiece = Tetromino.random();
    drawerPieces[0] = currentPiece;
    _layoutGrid();
  }

  /// Recalculate earnings/sec from pieces placed on the grid.
  void _recalcEarnings() {
    double eps = 0;
    for (final pp in placedPieces) {
      eps += MyGame.earningsForLevel(pp.piece.level);
    }
    game.earningsPerSecond = eps;
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
    placedPieces.add((
      piece: piece,
      originRow: originRow,
      originCol: originCol,
    ));
    _refreshCellColors();
    _recalcEarnings();
    return true;
  }

  void _refreshCellColors() {
    for (final child in children) {
      if (child is Cell) {
        final key = (child.row, child.col);
        if (_gridMergeHighlightCells.contains(key)) {
          child.paint = Paint()
            ..color = const Color(0xFFFF4444).withAlpha(140);
        } else if (_highlightedCells.contains(key)) {
          child.paint = Paint()
            ..color = (_highlightColor ?? const Color(0xFFFFFFFF)).withAlpha(
              140,
            );
        } else {
          child.paint = Paint()
            ..color =
                gridState[child.row][child.col] ?? const Color(0xFF2A2A4A);
        }
      }
    }
  }

  /// Update the highlighted preview cells based on current drag position.
  void updateHighlight(
    Tetromino? piece,
    Vector2? dragPos, {
    bool isFromGrid = false,
    int? dragSourceSlot,
  }) {
    _highlightedCells.clear();
    _highlightColor = null;
    _highlightedDrawerIndex = -1;
    _mergeHighlightIndex = -1;
    _gridMergeHighlightCells.clear();
    _trashHighlighted = false;
    if (piece != null && dragPos != null) {
      final snap = findSnapOrigin(piece, dragPos);
      if (snap != null) {
        _highlightColor = piece.color;
        for (final (r, c) in piece.cells) {
          _highlightedCells.add((snap.$1 + r, snap.$2 + c));
        }
      } else if (_isOverTrash(dragPos)) {
        _trashHighlighted = true;
      } else {
        // Check for grid merge target first.
        final gridTarget = findGridMergeTarget(piece, dragPos);
        if (gridTarget != null) {
          for (final (r, c) in gridTarget.piece.cells) {
            _gridMergeHighlightCells.add(
              (gridTarget.originRow + r, gridTarget.originCol + c),
            );
          }
        } else {
          // Check for merge target in drawer.
          final mergeIdx = _findMergeTarget(piece, dragPos.x, dragSourceSlot);
          if (mergeIdx != -1) {
            _mergeHighlightIndex = mergeIdx;
          } else if (isFromGrid) {
            final idx = _findNearestEmptySlot(dragPos.x);
            if (idx != -1) _highlightedDrawerIndex = idx;
          }
        }
      }
    }
    _refreshCellColors();
  }

  /// Check whether the drag position is over the trash holder.
  bool _isOverTrash(Vector2 dragPos) {
    if (_trashHolder == null || _drawerContainer == null) return false;
    final tx = _drawerContainer!.position.x + _trashHolder!.position.x;
    final ty = _drawerContainer!.position.y + _trashHolder!.position.y;
    final ts = _trashHolder!.size.x;
    return dragPos.x + cellSize > tx &&
        dragPos.x < tx + ts &&
        dragPos.y + cellSize > ty &&
        dragPos.y < ty + ts;
  }

  /// Find the nearest drawer slot that holds a piece of the same level for
  /// merging. [excludeSlot] is the slot the piece was dragged from (skip it).
  int _findMergeTarget(Tetromino piece, double canvasX, [int? excludeSlot]) {
    if (holders.isEmpty) return -1;
    int best = -1;
    double bestDist = double.infinity;
    for (int i = 0; i < MyGame.drawerSlots; i++) {
      if (i == excludeSlot) continue;
      final existing = drawerPieces[i];
      if (existing == null) continue;
      if (existing.level != piece.level) continue;
      final dcX = _drawerContainer?.position.x ?? 0;
      final slotCenterX = dcX + holders[i].position.x + holders[i].size.x / 2;
      final dist = (canvasX - slotCenterX).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    return best;
  }

  /// Merge the dragged [piece] with the piece at drawer slot [targetIdx].
  /// Produces a new random piece one level higher.
  void mergePieces(Tetromino piece, int targetIdx) {
    final newLevel = piece.level + 1;
    final merged = Tetromino.random(level: newLevel);
    drawerPieces[targetIdx] = merged;
    if (targetIdx < holders.length) holders[targetIdx].piece = merged;
    // Unlock in shop if needed.
    if (newLevel > game.maxUnlockedLevel) {
      game.unlockNextLevel();
    }
  }

  /// Find a placed piece on the grid under [dragPos] that can merge with
  /// [piece] (same level). Returns the target record or `null`.
  ({Tetromino piece, int originRow, int originCol})? findGridMergeTarget(
    Tetromino piece,
    Vector2 dragPos,
  ) {
    final step = cellSize + cellPadding;
    final centerX = dragPos.x + cellSize / 2;
    final centerY = dragPos.y + cellSize / 2;
    final col = ((centerX - mainOffsetX) / step).floor();
    final row = ((centerY - mainOffsetY) / step).floor();
    if (row < 0 || row >= MyGame.rows || col < 0 || col >= MyGame.columns) {
      return null;
    }
    final target = findPlacedPieceAt(row, col);
    if (target == null) return null;
    if (target.piece.level != piece.level) return null;
    return target;
  }

  /// Merge dragged [piece] with a placed [target] on the grid. The target is
  /// removed and the merged piece is placed in the drawer.
  void mergeWithGridPiece(
    Tetromino piece,
    ({Tetromino piece, int originRow, int originCol}) target,
  ) {
    removePlacedPiece(target);
    final newLevel = piece.level + 1;
    final merged = Tetromino.random(level: newLevel);
    returnPieceToDrawer(merged);
    if (newLevel > game.maxUnlockedLevel) {
      game.unlockNextLevel();
    }
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
  void removePlacedPiece(({Tetromino piece, int originRow, int originCol}) pp) {
    for (final (r, c) in pp.piece.cells) {
      gridState[pp.originRow + r][pp.originCol + c] = null;
    }
    placedPieces.remove(pp);
    _refreshCellColors();
    _recalcEarnings();
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
      final dcX = _drawerContainer?.position.x ?? 0;
      final slotCenterX = dcX + holders[i].position.x + holders[i].size.x / 2;
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
    int minR = 999, minC = 999;
    for (final (r, c) in piece.cells) {
      if (r < minR) minR = r;
      if (c < minC) minC = c;
    }

    final step = cellSize + cellPadding;

    // The top-left visible cell (minR, minC) is drawn at dragPos in the
    // DraggablePiece. Find which grid cell its centre is closest to.
    final anchorCenterX = dragPos.x + cellSize / 2;
    final anchorCenterY = dragPos.y + cellSize / 2;

    final snapCol =
        ((anchorCenterX - mainOffsetX - cellSize / 2 + step / 2) / step)
            .floor();
    final snapRow =
        ((anchorCenterY - mainOffsetY - cellSize / 2 + step / 2) / step)
            .floor();

    final originCol = snapCol - minC;
    final originRow = snapRow - minR;

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
    cellSize = [
      maxCellByHeight,
      maxCellByWidth,
    ].reduce((a, b) => a < b ? a : b);

    final mainGridWidth =
        MyGame.columns * (cellSize + cellPadding) + cellPadding;
    final mainGridHeight = MyGame.rows * (cellSize + cellPadding) + cellPadding;

    final holderSize = cellSize;
    final totalDrawerSlots = MyGame.drawerSlots + 1; // +1 for trash
    final drawerContentWidth =
        totalDrawerSlots * (holderSize + cellPadding) + cellPadding;
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

    // Drawer row (scrollable container)
    final drawerY = topY + mainGridHeight + gap;
    final drawerFits = drawerContentWidth <= screenSize.x;
    final drawerBaseX = drawerFits
        ? (screenSize.x - drawerContentWidth) / 2 + cellPadding
        : cellPadding;

    _drawerContainer = DrawerContainer(
      position: Vector2(0, drawerY),
      size: Vector2(screenSize.x, holderSize),
      board: this,
      contentWidth: drawerContentWidth,
    );
    add(_drawerContainer!);

    for (int i = 0; i < MyGame.drawerSlots; i++) {
      final x = drawerBaseX + i * (holderSize + cellPadding);
      final holder = PieceHolder(
        position: Vector2(x, 0),
        size: Vector2.all(holderSize),
        piece: drawerPieces[i],
        board: this,
        index: i,
      );
      holders.add(holder);
      _drawerContainer!.add(holder);
    }

    // Trash cell (last slot)
    final trashX =
        drawerBaseX + MyGame.drawerSlots * (holderSize + cellPadding);
    _trashHolder = TrashHolder(
      position: Vector2(trashX, 0),
      size: Vector2.all(holderSize),
      board: this,
    );
    _drawerContainer!.add(_trashHolder!);
  }

  @override
  void renderTree(Canvas canvas) {
    super.renderTree(canvas);
    _renderPlacedPieceLevels(canvas);
  }

  void _renderPlacedPieceLevels(Canvas canvas) {
    final step = cellSize + cellPadding;
    for (final pp in placedPieces) {
      int minR = 999, maxR = 0, minC = 999, maxC = 0;
      for (final (r, c) in pp.piece.cells) {
        final row = pp.originRow + r;
        final col = pp.originCol + c;
        if (row < minR) minR = row;
        if (row > maxR) maxR = row;
        if (col < minC) minC = col;
        if (col > maxC) maxC = col;
      }
      final centerX = mainOffsetX + (minC + maxC) / 2.0 * step + cellSize / 2;
      final centerY = mainOffsetY + (minR + maxR) / 2.0 * step + cellSize / 2;
      _drawLevelText(
        canvas,
        '${pp.piece.level}',
        centerX,
        centerY,
        cellSize * 0.5,
      );
    }
  }
}

/// Draw [text] centred at ([cx], [cy]) with a black outline for readability.
void _drawLevelText(
  Canvas canvas,
  String text,
  double cx,
  double cy,
  double fontSize,
) {
  final style = TextStyle(
    color: const Color(0xFFFFFFFF),
    fontSize: fontSize,
    fontWeight: FontWeight.w900,
    shadows: [
      Shadow(
        color: const Color(0xFF000000),
        blurRadius: 3,
        offset: const Offset(1, 1),
      ),
      Shadow(
        color: const Color(0xFF000000),
        blurRadius: 3,
        offset: const Offset(-1, -1),
      ),
      Shadow(
        color: const Color(0xFF000000),
        blurRadius: 3,
        offset: const Offset(1, -1),
      ),
      Shadow(
        color: const Color(0xFF000000),
        blurRadius: 3,
        offset: const Offset(-1, 1),
      ),
    ],
  );
  final builder = ParagraphBuilder(ParagraphStyle(textAlign: TextAlign.center))
    ..pushStyle(style)
    ..addText(text);
  final paragraph = builder.build()
    ..layout(ParagraphConstraints(width: fontSize * 3));
  canvas.drawParagraph(
    paragraph,
    Offset(cx - paragraph.width / 2, cy - paragraph.height / 2),
  );
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
      board!.updateHighlight(
        _draggedPlacement!.piece,
        _dragPiece!.position,
        isFromGrid: true,
      );
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
      } else if (board!._isOverTrash(_dragPiece!.position)) {
        // Trash the piece — just discard it.
        placed = true;
      } else {
        // Check for grid merge target.
        final gridTarget = board!.findGridMergeTarget(
          piece,
          _dragPiece!.position,
        );
        if (gridTarget != null) {
          board!.mergeWithGridPiece(piece, gridTarget);
          placed = true;
        } else {
          // Check for merge target in drawer.
          final mergeIdx =
              board!._findMergeTarget(piece, _dragPiece!.position.x);
          if (mergeIdx != -1) {
            board!.mergePieces(piece, mergeIdx);
            placed = true;
          } else {
            placed =
                board!.returnPieceToDrawer(piece, _dragPiece!.position.x);
          }
        }
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
class PieceHolder extends PositionComponent
    with DragCallbacks, TapCallbacks, SecondaryTapCallbacks {
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

  // ── tap to rotate ──

  @override
  void onTapUp(TapUpEvent event) {
    if (piece == null) return;
    piece!.rotateCW();
  }

  @override
  void onSecondaryTapUp(SecondaryTapUpEvent event) {
    if (piece == null) return;
    piece!.rotateCCW();
  }

  // ── drag handling ──

  @override
  void onDragStart(DragStartEvent event) {
    if (piece == null) return;
    super.onDragStart(event);

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
      board.updateHighlight(piece, _dragPiece!.position, dragSourceSlot: index);
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
    } else if (board._isOverTrash(_dragPiece!.position)) {
      // Trash the piece from drawer.
      piece = null;
      board.drawerPieces[index] = null;
    } else {
      // Check for grid merge target.
      final gridTarget = board.findGridMergeTarget(
        piece!,
        _dragPiece!.position,
      );
      if (gridTarget != null) {
        board.mergeWithGridPiece(piece!, gridTarget);
        piece = null;
        board.drawerPieces[index] = null;
      } else {
        // Check for drawer merge target.
        final mergeIdx = board._findMergeTarget(
          piece!,
          _dragPiece!.position.x,
          index,
        );
        if (mergeIdx != -1) {
          board.mergePieces(piece!, mergeIdx);
          piece = null;
          board.drawerPieces[index] = null;
        }
      }
    }

    board.updateHighlight(null, null);
    _dragPiece!.removeFromParent();
    _dragPiece = null;
  }

  // ── rendering ──

  @override
  void render(Canvas canvas) {
    final isHighlighted = board._highlightedDrawerIndex == index;
    final isMergeTarget = board._mergeHighlightIndex == index;
    canvas.drawRect(
      size.toRect(),
      Paint()
        ..color = isMergeTarget
            ? const Color(0xFF5A2020)
            : isHighlighted
            ? const Color(0xFF4A4A6A)
            : const Color(0xFF2A2A4A),
    );
    if (isMergeTarget) {
      canvas.drawRect(
        size.toRect(),
        Paint()
          ..color = const Color(0xFFFF4444)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    } else if (isHighlighted) {
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

    // Draw level number at the centre of the mini piece.
    final pieceCenterX = startX + totalW / 2;
    final pieceCenterY = startY + totalH / 2;
    _drawLevelText(
      canvas,
      '${piece!.level}',
      pieceCenterX,
      pieceCenterY,
      miniCellSize * 0.6,
    );
  }
}

// ──────────────────── DrawerContainer ────────────────────

/// Scrollable container for the bottom drawer row. Clips children to the
/// visible viewport and allows horizontal scrolling when content overflows.
class DrawerContainer extends PositionComponent with DragCallbacks {
  final GridBoard board;
  final double contentWidth;
  double _scrollX = 0;
  double _maxScrollX = 0;

  DrawerContainer({
    required super.position,
    required super.size,
    required this.board,
    required this.contentWidth,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _maxScrollX = (contentWidth - size.x).clamp(0.0, double.infinity);
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    canvas.clipRect(size.toRect());

    // Scroll indicators
    if (_maxScrollX > 0) {
      final arrowPaint = Paint()..color = const Color(0x66FFFFFF);
      final a = size.y * 0.2;
      final cy = size.y / 2;
      if (_scrollX > 1) {
        canvas.drawPath(
          Path()
            ..moveTo(a, cy - a)
            ..lineTo(2, cy)
            ..lineTo(a, cy + a)
            ..close(),
          arrowPaint,
        );
      }
      if (_scrollX < _maxScrollX - 1) {
        canvas.drawPath(
          Path()
            ..moveTo(size.x - a, cy - a)
            ..lineTo(size.x - 2, cy)
            ..lineTo(size.x - a, cy + a)
            ..close(),
          arrowPaint,
        );
      }
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    // Don't start scroll tracking if a child is dragging a piece.
    for (final child in children) {
      if (child is PieceHolder && child._dragPiece != null) return;
    }
    super.onDragStart(event);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_maxScrollX <= 0) return;
    _scrollX = (_scrollX - event.localDelta.x).clamp(0.0, _maxScrollX);
    _repositionItems();
  }

  void _repositionItems() {
    final step = board.cellSize + GridBoard.cellPadding;
    final totalSlots = MyGame.drawerSlots + 1;
    final totalWidth =
        totalSlots * (board.cellSize + GridBoard.cellPadding) +
        GridBoard.cellPadding;
    final fits = totalWidth <= size.x;
    final baseX = fits
        ? (size.x - totalWidth) / 2 + GridBoard.cellPadding
        : GridBoard.cellPadding - _scrollX;

    for (int i = 0; i < board.holders.length; i++) {
      board.holders[i].position.x = baseX + i * step;
    }
    board._trashHolder?.position.x = baseX + MyGame.drawerSlots * step;
  }
}

// ──────────────────── TrashHolder ────────────────────────

/// A special drawer cell that deletes any piece dropped on it.
class TrashHolder extends PositionComponent {
  final GridBoard board;

  TrashHolder({
    required super.position,
    required super.size,
    required this.board,
  });

  @override
  void render(Canvas canvas) {
    final highlighted = board._trashHighlighted;

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(4)),
      Paint()
        ..color = highlighted
            ? const Color(0x88000000)
            : const Color(0xFF2A2A4A),
    );

    // Border when highlighted
    if (highlighted) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(size.toRect(), const Radius.circular(4)),
        Paint()
          ..color = const Color(0xFFFF4444)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // Trash can icon
    _drawTrashIcon(canvas, size.x, size.y);
  }

  void _drawTrashIcon(Canvas canvas, double w, double h) {
    final paint = Paint()
      ..color = const Color(0xFF888888)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()..color = const Color(0xFF888888);

    final cx = w / 2;
    final iconH = h * 0.5;
    final iconW = w * 0.4;
    final top = (h - iconH) / 2;

    // Lid
    final lidY = top;
    final lidLeft = cx - iconW / 2 - iconW * 0.1;
    final lidRight = cx + iconW / 2 + iconW * 0.1;
    canvas.drawLine(Offset(lidLeft, lidY), Offset(lidRight, lidY), paint);

    // Lid handle
    final handleW = iconW * 0.3;
    final handleH = iconH * 0.12;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - handleW / 2, lidY - handleH, handleW, handleH),
        const Radius.circular(2),
      ),
      paint,
    );

    // Body (trapezoid-ish bucket)
    final bodyTop = lidY + iconH * 0.08;
    final bodyBottom = top + iconH;
    final bodyTopLeft = cx - iconW / 2;
    final bodyTopRight = cx + iconW / 2;
    final bodyBotLeft = cx - iconW / 2 + iconW * 0.08;
    final bodyBotRight = cx + iconW / 2 - iconW * 0.08;

    final path = Path()
      ..moveTo(bodyTopLeft, bodyTop)
      ..lineTo(bodyBotLeft, bodyBottom)
      ..lineTo(bodyBotRight, bodyBottom)
      ..lineTo(bodyTopRight, bodyTop)
      ..close();
    canvas.drawPath(path, fillPaint..color = const Color(0xFF3A3A5C));
    canvas.drawPath(path, paint);

    // Vertical lines on body
    final lineY1 = bodyTop + iconH * 0.15;
    final lineY2 = bodyBottom - iconH * 0.1;
    for (final frac in [0.35, 0.5, 0.65]) {
      final lx = cx - iconW / 2 + iconW * frac;
      canvas.drawLine(Offset(lx, lineY1), Offset(lx, lineY2), paint);
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
    int minR = 999, maxR = 0, minC = 999, maxC = 0;
    for (final (r, c) in piece.cells) {
      if (r < minR) minR = r;
      if (r > maxR) maxR = r;
      if (c < minC) minC = c;
      if (c > maxC) maxC = c;
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

    // Draw level number at the centre of the dragged piece.
    final bboxW = (maxC - minC + 1) * step;
    final bboxH = (maxR - minR + 1) * step;
    _drawLevelText(
      canvas,
      '${piece.level}',
      bboxW / 2,
      bboxH / 2,
      cellSize * 0.5,
    );
  }
}
