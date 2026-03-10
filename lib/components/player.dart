import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../space_shooter_game.dart';
import 'bullet.dart';
import 'enemy.dart';

class Player extends PositionComponent
    with HasGameReference<SpaceShooterGame>, KeyboardHandler, CollisionCallbacks {
  static const double _speed = 300;
  static const double _playerWidth = 40;
  static const double _playerHeight = 50;

  final Vector2 _velocity = Vector2.zero();
  double _shootCooldown = 0;
  static const double _shootInterval = 0.25;

  bool _moveLeft = false;
  bool _moveRight = false;
  bool _moveUp = false;
  bool _moveDown = false;
  bool _shooting = false;

  Player() : super(size: Vector2(_playerWidth, _playerHeight), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    resetPosition();
    add(RectangleHitbox());
  }

  void resetPosition() {
    if (game.isLoaded) {
      position = Vector2(game.size.x / 2, game.size.y - 80);
    }
  }

  @override
  void render(Canvas canvas) {
    // Ship body (triangle shape)
    final shipPath = Path()
      ..moveTo(size.x / 2, 0) // nose
      ..lineTo(size.x, size.y)  // bottom-right
      ..lineTo(size.x * 0.75, size.y * 0.75)
      ..lineTo(size.x * 0.25, size.y * 0.75)
      ..lineTo(0, size.y)       // bottom-left
      ..close();

    final shipPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF00E5FF), Color(0xFF2979FF)],
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));
    canvas.drawPath(shipPath, shipPaint);

    // Engine glow
    final enginePaint = Paint()..color = const Color(0xFFFF6D00);
    canvas.drawCircle(Offset(size.x * 0.35, size.y * 0.85), 4, enginePaint);
    canvas.drawCircle(Offset(size.x * 0.65, size.y * 0.85), 4, enginePaint);
  }

  @override
  void update(double dt) {
    super.update(dt);

    _velocity.setZero();
    if (_moveLeft) _velocity.x -= 1;
    if (_moveRight) _velocity.x += 1;
    if (_moveUp) _velocity.y -= 1;
    if (_moveDown) _velocity.y += 1;

    if (_velocity.length > 0) {
      _velocity.normalize();
      position.add(_velocity * _speed * dt);
    }

    // Clamp to screen bounds
    position.x = position.x.clamp(size.x / 2, game.size.x - size.x / 2);
    position.y = position.y.clamp(size.y / 2, game.size.y - size.y / 2);

    // Shooting
    _shootCooldown -= dt;
    if (_shooting && _shootCooldown <= 0) {
      _shootCooldown = _shootInterval;
      _shoot();
    }
  }

  void _shoot() {
    game.add(Bullet(position: Vector2(position.x, position.y - size.y / 2)));
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _moveLeft = keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA);
    _moveRight = keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD);
    _moveUp = keysPressed.contains(LogicalKeyboardKey.arrowUp) ||
        keysPressed.contains(LogicalKeyboardKey.keyW);
    _moveDown = keysPressed.contains(LogicalKeyboardKey.arrowDown) ||
        keysPressed.contains(LogicalKeyboardKey.keyS);
    _shooting = keysPressed.contains(LogicalKeyboardKey.space);

    return true;
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Enemy) {
      game.gameOver();
    }
  }
}
