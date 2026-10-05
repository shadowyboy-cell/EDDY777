#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
flutter doctor
flutter pub get
flutter clean
flutter build apk --release
echo "APK: build/app/outputs/flutter-apk/app-release.apk"
