import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../space_shooter_game.dart';

class ScoreDisplay extends PositionComponent
    with HasGameReference<SpaceShooterGame> {
  late TextPaint _textPaint;

  ScoreDisplay() : super(priority: 10);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = Vector2(16, 16);
    _textPaint = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 8)],
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    _textPaint.render(canvas, 'Score: ${game.score}', Vector2.zero());
  }
}
