import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../space_shooter_game.dart';

class Bullet extends PositionComponent
    with HasGameReference<SpaceShooterGame> {
  static const double _speed = 500;
  static const double _bulletWidth = 4;
  static const double _bulletHeight = 14;

  Bullet({required Vector2 position})
      : super(
          position: position,
          size: Vector2(_bulletWidth, _bulletHeight),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFF76FF03)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(2),
      ),
      paint,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y -= _speed * dt;

    if (position.y < -20) {
      removeFromParent();
    }
  }
}
