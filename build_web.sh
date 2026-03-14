#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

echo "Building web release..."
flutter build web --release

echo "Patching base href for itch.io..."
sed -i 's|<base href="/">|<base href="./">|' build/web/index.html

echo "Creating zip..."
rm -f flame_game_web.zip
cd build/web
zip -r ../../flame_game_web.zip .
cd ../..

echo "Done: flame_game_web.zip ($(du -h flame_game_web.zip | cut -f1))"
