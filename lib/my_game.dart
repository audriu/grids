import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'components/grid_board.dart';
import 'components/cash_hud.dart';

class MyGame extends FlameGame with HasCollisionDetection {
  static const int rows = 7;
  static const int columns = 7;
  static const int drawerSlots = 8;

  /// Total accumulated cash (euros).
  double cash = 0;

  /// Current earnings per second (computed from drawer contents).
  double earningsPerSecond = 0;

  late final CashHud _cashHud;

  @override
  Color backgroundColor() => const Color(0xFF1A1A2E);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(GridBoard());
    _cashHud = CashHud();
    add(_cashHud);
  }

  @override
  void update(double dt) {
    super.update(dt);
    cash += earningsPerSecond * dt;
  }

  /// Earnings per second for a given level: level 1 = 1, level 2 = 2, level 3 = 4, etc.
  static double earningsForLevel(int level) {
    if (level <= 0) return 0;
    // Each level doubles: 1, 2, 4, 8, ...
    return (1 << (level - 1)).toDouble();
  }
}
