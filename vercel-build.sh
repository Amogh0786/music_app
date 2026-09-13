#!/bin/bash
set -e

echo "==> Checking for Flutter SDK..."
if ! command -v flutter &> /dev/null; then
  echo "==> Downloading Flutter SDK into $HOME/flutter..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
  export PATH="$PATH:$HOME/flutter/bin"
fi

echo "==> Flutter version:"
flutter --version

echo "==> Building Flutter Web for production..."
flutter build web --release

echo "==> Build complete! Web directory created at build/web"
