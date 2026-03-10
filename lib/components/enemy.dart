
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../space_shooter_game.dart';
import 'bullet.dart';
import 'explosion.dart';

class Enemy extends PositionComponent
    with HasGameReference<SpaceShooterGame>, CollisionCallbacks {
  final double speed;
  static const double _enemySize = 36;

  Enemy({required Vector2 position, this.speed = 150})
      : super(
          position: position,
          size: Vector2.all(_enemySize),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    // Enemy ship body (inverted triangle / diamond shape)
    final path = Path()
      ..moveTo(size.x / 2, size.y)       // bottom point
      ..lineTo(size.x, size.y * 0.2)     // top-right
      ..lineTo(size.x * 0.7, 0)          // top-right-inner
      ..lineTo(size.x * 0.3, 0)          // top-left-inner
      ..lineTo(0, size.y * 0.2)          // top-left
      ..close();

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFF1744), Color(0xFFD50000)],
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));
    canvas.drawPath(path, paint);

    // Cockpit glow
    final cockpitPaint = Paint()..color = const Color(0xFFFFFF00);
    canvas.drawCircle(Offset(size.x / 2, size.y * 0.35), 4, cockpitPaint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += speed * dt;

    if (position.y > game.size.y + 50) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Bullet) {
      other.removeFromParent();
      game.add(Explosion(position: position.clone()));
      game.addScore(10);
      removeFromParent();
    }
  }
}
