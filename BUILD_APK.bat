@echo off
cd /d "%~dp0"
echo === اسم الميزانية APK Build ===
flutter doctor
if errorlevel 1 pause & exit /b 1
flutter pub get
if errorlevel 1 pause & exit /b 1
flutter clean
flutter build apk --release
if errorlevel 1 pause & exit /b 1
echo.
echo APK created at:
echo build\app\outputs\flutter-apk\app-release.apk
pause
