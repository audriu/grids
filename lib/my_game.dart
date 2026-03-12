import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'components/grid_board.dart';

class MyGame extends FlameGame {
  static const int rows = 7;
  static const int columns = 7;
  static const int drawerRows = 2;
  static const int drawerColumns = 4;

  @override
  Color backgroundColor() => const Color(0xFF1A1A2E);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(GridBoard());
  }
}
