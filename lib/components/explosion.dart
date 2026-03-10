import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class Explosion extends PositionComponent {
  double _lifetime = 0;
  static const double _duration = 0.4;

  Explosion({required Vector2 position})
      : super(position: position, size: Vector2.all(40), anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    final progress = _lifetime / _duration;
    final radius = 20.0 * progress;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    // Outer ring
    final outerPaint = Paint()
      ..color = Color.fromRGBO(255, 152, 0, opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), radius, outerPaint);

    // Inner glow
    final innerPaint = Paint()
      ..color = Color.fromRGBO(255, 235, 59, opacity * 0.7);
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), radius * 0.5, innerPaint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _lifetime += dt;
    if (_lifetime >= _duration) {
      removeFromParent();
    }
  }
}
