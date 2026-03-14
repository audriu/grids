import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../my_game.dart';
import 'tetromino.dart';

/// Full-screen shop overlay that lists purchasable piece levels.
class ShopOverlay extends PositionComponent
    with TapCallbacks, HasGameReference<MyGame> {
  ShopOverlay() : super(priority: 300);

  static const double _panelWidth = 220;
  static const double _rowHeight = 60;
  static const double _padding = 16;
  static const double _cornerRadius = 12;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = game.size;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void render(Canvas canvas) {
    final screenW = game.size.x;
    final screenH = game.size.y;

    // Dim background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, screenW, screenH),
      Paint()..color = const Color(0xAA000000),
    );

    // Panel
    final totalRows = game.maxUnlockedLevel + 1; // unlocked + 1 locked
    final panelHeight =
        _padding * 2 + totalRows * _rowHeight + 40; // 40 for title
    final panelX = (screenW - _panelWidth) / 2;
    final panelY = (screenH - panelHeight) / 2;

    final panelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(panelX, panelY, _panelWidth, panelHeight),
      const Radius.circular(_cornerRadius),
    );
    canvas.drawRRect(panelRect, Paint()..color = const Color(0xFF2A2A4A));
    canvas.drawRRect(
      panelRect,
      Paint()
        ..color = const Color(0xFF8888FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Title
    final titleStyle = TextStyle(
      color: const Color(0xFFFFFFFF),
      fontSize: 18,
      fontWeight: FontWeight.bold,
    );
    final titleBuilder =
        ParagraphBuilder(ParagraphStyle(textAlign: TextAlign.center))
          ..pushStyle(titleStyle)
          ..addText('Shop');
    final titleP = titleBuilder.build()
      ..layout(ParagraphConstraints(width: _panelWidth - _padding * 2));
    canvas.drawParagraph(titleP, Offset(panelX + _padding, panelY + _padding));

    final rowStartY = panelY + _padding + 40;

    // Unlocked levels
    for (int lvl = 1; lvl <= game.maxUnlockedLevel; lvl++) {
      final y = rowStartY + (lvl - 1) * _rowHeight;
      _renderShopRow(canvas, panelX, y, lvl);
    }

    // Locked placeholder
    final lockedY = rowStartY + game.maxUnlockedLevel * _rowHeight;
    _renderLockedRow(canvas, panelX, lockedY);
  }

  void _renderShopRow(Canvas canvas, double panelX, double y, int level) {
    final piece = game.shopOffers[level];
    final price = game.shopPrices[level] ?? 0;
    final canAfford = game.cash >= price;

    final rowX = panelX + _padding;
    final rowW = _panelWidth - _padding * 2;

    // Row background
    final rowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(rowX, y, rowW, _rowHeight - 4),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      rowRect,
      Paint()
        ..color = canAfford ? const Color(0xFF3A3A5C) : const Color(0xFF252540),
    );

    // Mini piece preview
    if (piece != null) {
      _renderMiniPiece(canvas, piece, rowX + 6, y + 6, _rowHeight - 16);
    }

    // Level label
    final lvlStyle = TextStyle(
      color: const Color(0xFFCCCCCC),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
    final lvlBuilder =
        ParagraphBuilder(ParagraphStyle(textAlign: TextAlign.left))
          ..pushStyle(lvlStyle)
          ..addText('Lv.$level');
    final lvlP = lvlBuilder.build()..layout(ParagraphConstraints(width: 40));
    canvas.drawParagraph(lvlP, Offset(rowX + _rowHeight - 6, y + 8));

    // Price
    final priceStyle = TextStyle(
      color: canAfford ? const Color(0xFFAAFFAA) : const Color(0xFFFF8888),
      fontSize: 13,
      fontWeight: FontWeight.bold,
    );
    final priceBuilder =
        ParagraphBuilder(ParagraphStyle(textAlign: TextAlign.right))
          ..pushStyle(priceStyle)
          ..addText('€${price.toStringAsFixed(1)}');
    final priceP = priceBuilder.build()
      ..layout(ParagraphConstraints(width: 70));
    canvas.drawParagraph(priceP, Offset(rowX + rowW - 76, y + 20));
  }

  void _renderLockedRow(Canvas canvas, double panelX, double y) {
    final rowX = panelX + _padding;
    final rowW = _panelWidth - _padding * 2;
    final nextLevel = game.maxUnlockedLevel + 1;

    final rowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(rowX, y, rowW, _rowHeight - 4),
      const Radius.circular(6),
    );
    canvas.drawRRect(rowRect, Paint()..color = const Color(0xFF1E1E35));

    final style = TextStyle(
      color: const Color(0xFF666688),
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    final builder =
        ParagraphBuilder(ParagraphStyle(textAlign: TextAlign.center))
          ..pushStyle(style)
          ..addText('🔒 Level $nextLevel Locked');
    final p = builder.build()..layout(ParagraphConstraints(width: rowW));
    canvas.drawParagraph(p, Offset(rowX, y + (_rowHeight - 4 - p.height) / 2));
  }

  void _renderMiniPiece(
    Canvas canvas,
    Tetromino piece,
    double x,
    double y,
    double boxSize,
  ) {
    int minR = 999, maxR = 0, minC = 999, maxC = 0;
    for (final (r, c) in piece.cells) {
      if (r < minR) minR = r;
      if (r > maxR) maxR = r;
      if (c < minC) minC = c;
      if (c > maxC) maxC = c;
    }
    final rows = maxR - minR + 1;
    final cols = maxC - minC + 1;
    final cellSize = boxSize / (rows > cols ? rows : cols);
    final totalW = cols * cellSize;
    final totalH = rows * cellSize;
    final startX = x + (boxSize - totalW) / 2;
    final startY = y + (boxSize - totalH) / 2;
    final paint = Paint()..color = piece.color;

    for (final (r, c) in piece.cells) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            startX + (c - minC) * cellSize + 0.5,
            startY + (r - minR) * cellSize + 0.5,
            cellSize - 1,
            cellSize - 1,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  // ── tap handling ──

  @override
  bool containsPoint(Vector2 point) => true;

  @override
  void onTapDown(TapDownEvent event) {
    // Consume the event so it doesn't propagate to components below.
    event.handled = true;
  }

  @override
  void onTapUp(TapUpEvent event) {
    event.handled = true;
    final pos = event.canvasPosition;
    final screenW = game.size.x;
    final screenH = game.size.y;

    final totalRows = game.maxUnlockedLevel + 1;
    final panelHeight = _padding * 2 + totalRows * _rowHeight + 40;
    final panelX = (screenW - _panelWidth) / 2;
    final panelY = (screenH - panelHeight) / 2;
    final rowStartY = panelY + _padding + 40;

    // Check if tap is inside an unlocked row
    for (int lvl = 1; lvl <= game.maxUnlockedLevel; lvl++) {
      final rowY = rowStartY + (lvl - 1) * _rowHeight;
      final rowRect = Rect.fromLTWH(
        panelX + _padding,
        rowY,
        _panelWidth - _padding * 2,
        _rowHeight - 4,
      );
      if (rowRect.contains(Offset(pos.x, pos.y))) {
        game.buyPiece(lvl);
        return;
      }
    }

    // Tap outside panel → close
    final panelRect = Rect.fromLTWH(panelX, panelY, _panelWidth, panelHeight);
    if (!panelRect.contains(Offset(pos.x, pos.y))) {
      removeFromParent();
    }
  }
}
