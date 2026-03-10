import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'components/player.dart';
import 'components/enemy.dart';
import 'components/star_background.dart';
import 'components/score_display.dart';

class SpaceShooterGame extends FlameGame
    with HasKeyboardHandlerComponents, HasCollisionDetection {
  late Player player;
  final Random _random = Random();
  int score = 0;
  double _enemySpawnTimer = 0;
  double _enemySpawnInterval = 1.5;
  bool isGameOver = false;

  @override
  Color backgroundColor() => const Color(0xFF0A0A2E);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    add(StarBackground());

    player = Player();
    add(player);

    add(ScoreDisplay());
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isGameOver) return;

    _enemySpawnTimer += dt;
    if (_enemySpawnTimer >= _enemySpawnInterval) {
      _enemySpawnTimer = 0;
      _spawnEnemy();

      // Gradually increase difficulty
      if (_enemySpawnInterval > 0.4) {
        _enemySpawnInterval -= 0.02;
      }
    }
  }

  void _spawnEnemy() {
    final x = _random.nextDouble() * (size.x - 40) + 20;
    final speed = 100.0 + _random.nextDouble() * 150;
    add(Enemy(position: Vector2(x, -40), speed: speed));
  }

  void addScore(int points) {
    score += points;
  }

  void gameOver() {
    if (isGameOver) return;
    isGameOver = true;
    overlays.add('GameOver');
    pauseEngine();
  }

  void restart() {
    overlays.remove('GameOver');
    score = 0;
    _enemySpawnTimer = 0;
    _enemySpawnInterval = 1.5;
    isGameOver = false;

    // Remove all enemies and bullets
    children
        .whereType<Enemy>()
        .toList()
        .forEach((e) => e.removeFromParent());
    children
        .where((c) => c is! Player && c is! StarBackground && c is! ScoreDisplay)
        .toList()
        .forEach((c) {
      if (c is Enemy) c.removeFromParent();
    });

    // Reset player position
    player.resetPosition();

    resumeEngine();
  }
}
