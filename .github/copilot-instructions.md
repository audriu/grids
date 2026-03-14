# Copilot Instructions

## Project

Flutter + Flame idle game. Grid-based piece placement with a drawer, shop, merging, and trash deletion.

## Tech Stack

- Flutter (Dart)
- Flame game engine
- Target platform: Web (HTML5)

## Building for itch.io

Run the build script:

```bash
./build_web.sh
```

This does the following:
1. `flutter build web --release`
2. Patches `build/web/index.html` — changes `<base href="/">` to `<base href="./">` (required for itch.io's iframe hosting, otherwise assets return 403)
3. Zips `build/web/` into `flame_game_web.zip` at the project root, replacing any existing zip

Upload `flame_game_web.zip` to itch.io with project kind set to **HTML** and **"This file will be played in the browser"** checked.

## Key Files

- `lib/main.dart` — app entry point
- `lib/my_game.dart` — game state, shop logic, earnings
- `lib/components/grid_board.dart` — grid, drawer, trash cell, drag-and-drop
- `lib/components/tetromino.dart` — piece shapes and levels
- `lib/components/cash_hud.dart` — HUD and shop button
- `lib/components/shop_overlay.dart` — shop panel overlay
- `build_web.sh` — itch.io build + zip script
