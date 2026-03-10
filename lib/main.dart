import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'space_shooter_game.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: GameWidget<SpaceShooterGame>.controlled(
          gameFactory: SpaceShooterGame.new,
          overlayBuilderMap: {
            'GameOver': (context, game) => _GameOverOverlay(game: game),
          },
        ),
      ),
    ),
  );
}

class _GameOverOverlay extends StatelessWidget {
  final SpaceShooterGame game;
  const _GameOverOverlay({required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'GAME OVER',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Score: ${game.score}',
              style: const TextStyle(color: Colors.white, fontSize: 28),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                game.restart();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text(
                'PLAY AGAIN',
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
