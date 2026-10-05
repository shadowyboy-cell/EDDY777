#!/bin/sh
# Fallback wrapper for environments where Gradle is installed on PATH.
# Flutter normally uses this script through the Android project.
if command -v gradle >/dev/null 2>&1; then
  exec gradle "$@"
fi
echo "Gradle executable not found. Install Android Studio/Gradle or regenerate the wrapper with:"
echo "cd android && gradle wrapper"
exit 1
