import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'components/grid_board.dart';
import 'components/cash_hud.dart';
import 'components/tetromino.dart';

class MyGame extends FlameGame with HasCollisionDetection {
  static const int rows = 7;
  static const int columns = 7;
  static const int drawerSlots = 8;

  /// Total accumulated cash (euros).
  double cash = 0;

  /// Current earnings per second (computed from drawer contents).
  double earningsPerSecond = 0;

  /// Highest unlocked shop level (starts at 1).
  int maxUnlockedLevel = 1;

  /// Current price for each level. Key = level, value = price in euros.
  /// Base prices: level 1 = 1, level 2 = 2, level 3 = 4, …  (2^(level-1)).
  /// Each purchase multiplies that level's price by 1.5.
  final Map<int, double> shopPrices = {};

  /// The random piece currently offered in each shop row. Key = level.
  final Map<int, Tetromino> shopOffers = {};

  late final CashHud _cashHud;
  late final GridBoard _gridBoard;

  GridBoard get gridBoard => _gridBoard;

  @override
  Color backgroundColor() => const Color(0xFF1A1A2E);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _gridBoard = GridBoard();
    add(_gridBoard);
    _cashHud = CashHud();
    add(_cashHud);
    _initShop();
  }

  void _initShop() {
    for (int lvl = 1; lvl <= maxUnlockedLevel; lvl++) {
      shopPrices.putIfAbsent(lvl, () => _basePrice(lvl));
      shopOffers.putIfAbsent(lvl, () => Tetromino.random(level: lvl));
    }
  }

  /// Base price for a level before any purchases.
  static double _basePrice(int level) => (1 << (level - 1)).toDouble();

  /// Try to buy the piece offered at [level]. Returns true on success.
  bool buyPiece(int level) {
    final price = shopPrices[level];
    if (price == null) return false;
    if (cash < price) return false;

    final piece = shopOffers[level];
    if (piece == null) return false;

    // Try to place in drawer
    if (!_gridBoard.returnPieceToDrawer(piece)) return false;

    cash -= price;
    shopPrices[level] = price * 1.5;
    shopOffers[level] = Tetromino.random(level: level);
    return true;
  }

  /// Unlock the next level in the shop.
  void unlockNextLevel() {
    maxUnlockedLevel++;
    shopPrices.putIfAbsent(
      maxUnlockedLevel,
      () => _basePrice(maxUnlockedLevel),
    );
    shopOffers.putIfAbsent(
      maxUnlockedLevel,
      () => Tetromino.random(level: maxUnlockedLevel),
    );
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
