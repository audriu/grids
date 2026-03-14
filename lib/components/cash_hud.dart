import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../my_game.dart';
import 'shop_overlay.dart';

/// Heads-up display showing total cash and earnings per second in the top-right.
class CashHud extends PositionComponent with HasGameReference<MyGame> {
  CashHud() : super(priority: 200);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(ShopButton());
  }

  @override
  void render(Canvas canvas) {
    final cashText = '€${game.cash.toStringAsFixed(1)}';
    final epsText = '€${game.earningsPerSecond.toStringAsFixed(2)}/s';

    final cashStyle = TextStyle(
      color: const Color(0xFFFFFFFF),
      fontSize: 20,
      fontWeight: FontWeight.bold,
    );
    final epsStyle = TextStyle(
      color: const Color(0xFFAAFFAA),
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );

    // Cash line
    final cashBuilder =
        ParagraphBuilder(ParagraphStyle(textAlign: TextAlign.right))
          ..pushStyle(cashStyle)
          ..addText(cashText);
    final cashParagraph = cashBuilder.build()
      ..layout(ParagraphConstraints(width: 200));

    // Earnings line
    final epsBuilder =
        ParagraphBuilder(ParagraphStyle(textAlign: TextAlign.right))
          ..pushStyle(epsStyle)
          ..addText(epsText);
    final epsParagraph = epsBuilder.build()
      ..layout(ParagraphConstraints(width: 200));

    final screenW = game.size.x;
    const margin = 12.0;
    final x = screenW - 200 - margin;

    canvas.drawParagraph(cashParagraph, Offset(x, margin));
    canvas.drawParagraph(
      epsParagraph,
      Offset(x, margin + cashParagraph.height + 4),
    );
  }
}

/// Shop button rendered in the top-left corner.
class ShopButton extends PositionComponent
    with TapCallbacks, HasGameReference<MyGame> {
  static const double _size = 44;
  static const double _margin = 12;

  ShopButton()
    : super(
        position: Vector2(_margin, _margin),
        size: Vector2.all(_size),
        priority: 210,
      );

  @override
  void render(Canvas canvas) {
    // Background rounded rect
    final bgPaint = Paint()..color = const Color(0xFF3A3A5C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(8)),
      bgPaint,
    );

    // Border
    final borderPaint = Paint()
      ..color = const Color(0xFF8888FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(8)),
      borderPaint,
    );

    // "Shop" label
    final style = TextStyle(
      color: const Color(0xFFFFFFFF),
      fontSize: 13,
      fontWeight: FontWeight.bold,
    );
    final builder =
        ParagraphBuilder(ParagraphStyle(textAlign: TextAlign.center))
          ..pushStyle(style)
          ..addText('Shop');
    final paragraph = builder.build()
      ..layout(ParagraphConstraints(width: _size));
    canvas.drawParagraph(paragraph, Offset(0, (_size - paragraph.height) / 2));
  }

  @override
  void onTapUp(TapUpEvent event) {
    // Toggle shop overlay
    final existing = game.children.whereType<ShopOverlay>();
    if (existing.isNotEmpty) {
      existing.first.removeFromParent();
    } else {
      game.add(ShopOverlay());
    }
  }
}
