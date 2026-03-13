import 'dart:ui';

import 'package:flame/components.dart';

import '../my_game.dart';

/// Heads-up display showing total cash and earnings per second in the top-right.
class CashHud extends PositionComponent with HasGameReference<MyGame> {
  CashHud() : super(priority: 200);

  @override
  void render(Canvas canvas) {
    final cashText = '€${game.cash.toStringAsFixed(1)}';
    final epsText = '€${game.earningsPerSecond.toStringAsFixed(1)}/s';

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
    final cashBuilder = ParagraphBuilder(
      ParagraphStyle(textAlign: TextAlign.right),
    )
      ..pushStyle(cashStyle)
      ..addText(cashText);
    final cashParagraph = cashBuilder.build()
      ..layout(ParagraphConstraints(width: 200));

    // Earnings line
    final epsBuilder = ParagraphBuilder(
      ParagraphStyle(textAlign: TextAlign.right),
    )
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
