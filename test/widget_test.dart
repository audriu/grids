import 'package:flutter_test/flutter_test.dart';
import 'package:flame_game/space_shooter_game.dart';

void main() {
  test('SpaceShooterGame can be instantiated', () {
    final game = SpaceShooterGame();
    expect(game.score, 0);
  });
}
