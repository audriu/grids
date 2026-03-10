import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../space_shooter_game.dart';

class StarBackground extends PositionComponent
    with HasGameReference<SpaceShooterGame> {
  final List<_Star> _stars = [];
  final Random _random = Random();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = game.size;
    priority = -1;

    for (int i = 0; i < 120; i++) {
      _stars.add(_Star(
        x: _random.nextDouble() * size.x,
        y: _random.nextDouble() * size.y,
        speed: 20 + _random.nextDouble() * 80,
        radius: 0.5 + _random.nextDouble() * 1.5,
        brightness: 0.3 + _random.nextDouble() * 0.7,
      ));
    }
  }

  @override
  void render(Canvas canvas) {
    for (final star in _stars) {
      final paint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, star.brightness);
      canvas.drawCircle(Offset(star.x, star.y), star.radius, paint);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (final star in _stars) {
      star.y += star.speed * dt;
      if (star.y > size.y) {
        star.y = 0;
        star.x = _random.nextDouble() * size.x;
      }
    }
  }
}

class _Star {
  double x;
  double y;
  final double speed;
  final double radius;
  final double brightness;

  _Star({
    required this.x,
    required this.y,
    required this.speed,
    required this.radius,
    required this.brightness,
  });
}
